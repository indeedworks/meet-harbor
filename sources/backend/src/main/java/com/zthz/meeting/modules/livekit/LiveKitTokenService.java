package com.zthz.meeting.modules.livekit;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.Duration;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.Map;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.stereotype.Service;

@Service
public class LiveKitTokenService {

    private final String liveKitUrl;
    private final String apiKey;
    private final JwtEncoder jwtEncoder;
    private final JwtDecoder jwtDecoder;

    public LiveKitTokenService(
            @Value("${app.livekit.url}") String liveKitUrl,
            @Value("${app.livekit.api-key}") String apiKey,
            @Value("${app.livekit.api-secret}") String apiSecret
    ) {
        byte[] secretBytes = apiSecret.getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < 32) {
            throw new IllegalStateException("LIVEKIT_API_SECRET must be at least 32 bytes for HS256 token signing");
        }
        this.liveKitUrl = liveKitUrl;
        this.apiKey = apiKey;
        this.jwtEncoder = new NimbusJwtEncoder(new ImmutableSecret<>(secretBytes));
        SecretKey secretKey = new SecretKeySpec(secretBytes, "HmacSHA256");
        this.jwtDecoder = NimbusJwtDecoder.withSecretKey(secretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
    }

    public LiveKitConnection createParticipantToken(String roomName, String identity, String displayName) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plus(2, ChronoUnit.HOURS);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(apiKey)
                .subject(identity)
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .claim("name", displayName)
                .claim("video", Map.of(
                        "roomJoin", true,
                        "room", roomName,
                        "canPublish", true,
                        "canSubscribe", true,
                        "canPublishData", true
                ))
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new LiveKitConnection(liveKitUrl, roomName, token, expiresAt);
    }

    public String createRoomServiceToken(Map<String, Object> videoGrant) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plus(10, ChronoUnit.MINUTES);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(apiKey)
                .subject("remote-meeting-backend")
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .claim("video", videoGrant)
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    public void verifyWebhook(String authorizationHeader, String rawBody) {
        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            throw new IllegalArgumentException("LiveKit webhook missing bearer token");
        }
        Jwt jwt = jwtDecoder.decode(authorizationHeader.substring("Bearer ".length()));
        String payloadHash = jwt.getClaimAsString("sha256");
        if (payloadHash == null || payloadHash.isBlank()) {
            throw new IllegalArgumentException("LiveKit webhook missing payload hash");
        }
        String actualHash = sha256Hex(rawBody);
        if (!payloadHash.equalsIgnoreCase(actualHash)) {
            throw new IllegalArgumentException("LiveKit webhook payload hash mismatch");
        }
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 digest is unavailable", exception);
        }
    }

    public record LiveKitConnection(
            String url,
            String roomName,
            String participantToken,
            Instant expiresAt
    ) {
    }
}
