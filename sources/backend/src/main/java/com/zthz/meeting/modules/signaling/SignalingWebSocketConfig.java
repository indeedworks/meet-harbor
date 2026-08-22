package com.zthz.meeting.modules.signaling;

import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class SignalingWebSocketConfig implements WebSocketConfigurer {

    private final SignalingWebSocketHandler signalingWebSocketHandler;
    private final List<String> allowedOrigins;

    public SignalingWebSocketConfig(
            SignalingWebSocketHandler signalingWebSocketHandler,
            @Value("${app.security.cors-allowed-origin-patterns}") List<String> allowedOrigins
    ) {
        this.signalingWebSocketHandler = signalingWebSocketHandler;
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(signalingWebSocketHandler, "/ws/signaling")
                .setAllowedOriginPatterns(allowedOrigins.toArray(String[]::new));
    }
}

