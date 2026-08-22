package com.zthz.meeting.modules.admin.users;

import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.admin.users.UserService.AdminUserResponse;
import com.zthz.meeting.modules.admin.users.UserService.CreateUserRequest;
import com.zthz.meeting.modules.admin.users.UserService.ResetPasswordResponse;
import com.zthz.meeting.modules.admin.users.UserService.UpdateNicknameRequest;
import com.zthz.meeting.modules.admin.users.UserService.UpdateStatusRequest;
import com.zthz.meeting.modules.logs.OperationLogService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final UserService userService;
    private final OperationLogService operationLogService;

    public AdminUserController(UserService userService, OperationLogService operationLogService) {
        this.userService = userService;
        this.operationLogService = operationLogService;
    }

    @GetMapping
    public ApiResponse<List<AdminUserResponse>> listUsers() {
        return ApiResponse.ok(userService.listUsers());
    }

    @PostMapping
    public ApiResponse<AdminUserResponse> createUser(
            @Valid @RequestBody CreateUserHttpRequest request,
            HttpServletRequest httpRequest
    ) {
        AdminUserResponse user = userService.createUser(new CreateUserRequest(
                request.account(),
                request.nickname(),
                request.role()
        ));
        operationLogService.record("CREATE_USER", "USER", user.id(), "{\"account\":\"" + user.account() + "\"}", httpRequest);
        return ApiResponse.ok(user);
    }

    @PatchMapping("/{id}/nickname")
    public ApiResponse<AdminUserResponse> updateNickname(
            @PathVariable Long id,
            @Valid @RequestBody UpdateNicknameHttpRequest request,
            HttpServletRequest httpRequest
    ) {
        AdminUserResponse user = userService.updateNickname(id, new UpdateNicknameRequest(request.nickname()));
        operationLogService.record("UPDATE_USER", "USER", user.id(), "{\"nickname\":\"" + user.nickname() + "\"}", httpRequest);
        return ApiResponse.ok(user);
    }

    @PatchMapping("/{id}/status")
    public ApiResponse<AdminUserResponse> updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody UpdateStatusHttpRequest request,
            HttpServletRequest httpRequest
    ) {
        AdminUserResponse user = userService.updateStatus(id, new UpdateStatusRequest(request.status()));
        String action = "ENABLED".equals(user.status()) ? "ENABLE_USER" : "DISABLE_USER";
        operationLogService.record(action, "USER", user.id(), "{\"status\":\"" + user.status() + "\"}", httpRequest);
        return ApiResponse.ok(user);
    }

    @PostMapping("/{id}/reset-password")
    public ApiResponse<ResetPasswordResponse> resetPassword(@PathVariable Long id, HttpServletRequest httpRequest) {
        ResetPasswordResponse response = userService.resetPassword(id);
        operationLogService.record("RESET_PASSWORD", "USER", id, null, httpRequest);
        return ApiResponse.ok(response);
    }

    public record CreateUserHttpRequest(
            @NotBlank String account,
            @NotBlank String nickname,
            @NotBlank String role
    ) {
    }

    public record UpdateNicknameHttpRequest(@NotBlank String nickname) {
    }

    public record UpdateStatusHttpRequest(@NotBlank String status) {
    }
}
