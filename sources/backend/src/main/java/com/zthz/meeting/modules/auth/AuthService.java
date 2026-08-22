package com.zthz.meeting.modules.auth;

import com.zthz.meeting.modules.admin.users.UserEntity;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final JwtEncoder jwtEncoder;
    private final long accessTokenTtlMinutes;

    public AuthService(
            JwtEncoder jwtEncoder,
            @Value("${app.security.access-token-ttl-minutes}") long accessTokenTtlMinutes
    ) {
        this.jwtEncoder = jwtEncoder;
        this.accessTokenTtlMinutes = accessTokenTtlMinutes;
    }

    public TokenResult issueAccessToken(UserEntity user) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plus(accessTokenTtlMinutes, ChronoUnit.MINUTES);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("remote-meeting-backend")
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .subject(user.getAccount())
                .claim("uid", user.getId())
                .claim("nickname", user.getNickname())
                .claim("roles", List.of(user.getRole()))
                .build();

        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new TokenResult(token, expiresAt);
    }

    public record TokenResult(String accessToken, Instant expiresAt) {
    }
}
