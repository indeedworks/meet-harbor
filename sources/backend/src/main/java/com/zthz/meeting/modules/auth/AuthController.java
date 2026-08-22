package com.zthz.meeting.modules.auth;

import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.admin.users.UserEntity;
import com.zthz.meeting.modules.admin.users.UserService;
import com.zthz.meeting.modules.auth.AuthService.TokenResult;
import com.zthz.meeting.modules.logs.OperationLogService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;
    private final PasswordEncoder passwordEncoder;
    private final AuthService authService;
    private final OperationLogService operationLogService;

    public AuthController(
            UserService userService,
            PasswordEncoder passwordEncoder,
            AuthService authService,
            OperationLogService operationLogService
    ) {
        this.userService = userService;
        this.passwordEncoder = passwordEncoder;
        this.authService = authService;
        this.operationLogService = operationLogService;
    }

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        UserEntity user = userService.requireEnabledUserByAccount(request.account());
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new IllegalArgumentException("账号或密码错误");
        }
        userService.updateLastLoginAt(user);
        TokenResult token = authService.issueAccessToken(user);
        operationLogService.recordAs(user, "LOGIN", "USER", user.getId(), "{\"account\":\"" + user.getAccount() + "\"}", httpRequest);

        return ApiResponse.ok(new LoginResponse(
                token.accessToken(),
                token.expiresAt(),
                user.getAccount(),
                user.getNickname(),
                user.getRole()
        ));
    }

    @PostMapping("/change-password")
    public ApiResponse<Void> changePassword(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ChangePasswordRequest request,
            HttpServletRequest httpRequest
    ) {
        UserEntity user = userService.requireEnabledUserByAccount(jwt.getSubject());
        if (!passwordEncoder.matches(request.oldPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("原密码错误");
        }
        userService.changePassword(user.getId(), request.newPassword());
        operationLogService.record("CHANGE_PASSWORD", "USER", user.getId(), "{\"account\":\"" + user.getAccount() + "\"}", httpRequest);
        return ApiResponse.ok();
    }

    public record LoginRequest(
            @NotBlank String account,
            @NotBlank String password
    ) {
    }

    public record LoginResponse(
            String accessToken,
            Instant expiresAt,
            String account,
            String nickname,
            String role
    ) {
    }

    public record ChangePasswordRequest(
            @NotBlank String oldPassword,
            @NotBlank String newPassword
    ) {
    }
}
