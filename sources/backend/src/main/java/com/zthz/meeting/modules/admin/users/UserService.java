package com.zthz.meeting.modules.admin.users;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    public static final String DEFAULT_PASSWORD = "Aa123456";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public List<AdminUserResponse> listUsers() {
        return userRepository.findAll().stream()
                .map(AdminUserResponse::from)
                .toList();
    }

    @Transactional
    public AdminUserResponse createUser(CreateUserRequest request) {
        validateRole(request.role());
        if (userRepository.existsByAccount(request.account())) {
            throw new IllegalArgumentException("登录账号已存在");
        }

        OffsetDateTime now = OffsetDateTime.now();
        UserEntity user = new UserEntity();
        user.setAccount(request.account());
        user.setNickname(request.nickname());
        user.setPasswordHash(passwordEncoder.encode(DEFAULT_PASSWORD));
        user.setRole(request.role());
        user.setStatus("ENABLED");
        user.setCreatedAt(now);
        user.setUpdatedAt(now);
        return AdminUserResponse.from(userRepository.save(user));
    }

    @Transactional
    public AdminUserResponse updateNickname(Long id, UpdateNicknameRequest request) {
        UserEntity user = requireUser(id);
        user.setNickname(request.nickname());
        user.setUpdatedAt(OffsetDateTime.now());
        return AdminUserResponse.from(userRepository.save(user));
    }

    @Transactional
    public AdminUserResponse updateStatus(Long id, UpdateStatusRequest request) {
        validateStatus(request.status());
        UserEntity user = requireUser(id);
        user.setStatus(request.status());
        user.setUpdatedAt(OffsetDateTime.now());
        return AdminUserResponse.from(userRepository.save(user));
    }

    @Transactional
    public ResetPasswordResponse resetPassword(Long id) {
        UserEntity user = requireUser(id);
        user.setPasswordHash(passwordEncoder.encode(DEFAULT_PASSWORD));
        user.setUpdatedAt(OffsetDateTime.now());
        userRepository.save(user);
        return new ResetPasswordResponse(DEFAULT_PASSWORD);
    }

    @Transactional
    public void changePassword(Long id, String newPassword) {
        UserEntity user = requireUser(id);
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setUpdatedAt(OffsetDateTime.now());
        userRepository.save(user);
    }

    @Transactional
    public void updateLastLoginAt(UserEntity user) {
        user.setLastLoginAt(OffsetDateTime.now());
        user.setUpdatedAt(OffsetDateTime.now());
        userRepository.save(user);
    }

    @Transactional(readOnly = true)
    public UserEntity requireEnabledUserByAccount(String account) {
        UserEntity user = userRepository.findByAccount(account)
                .orElseThrow(() -> new IllegalArgumentException("账号或密码错误"));
        if (!"ENABLED".equals(user.getStatus())) {
            throw new IllegalArgumentException("账号已被禁用");
        }
        return user;
    }

    private UserEntity requireUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
    }

    private void validateRole(String role) {
        if (!"ADMIN".equals(role) && !"USER".equals(role)) {
            throw new IllegalArgumentException("用户角色不正确");
        }
    }

    private void validateStatus(String status) {
        if (!"ENABLED".equals(status) && !"DISABLED".equals(status)) {
            throw new IllegalArgumentException("用户状态不正确");
        }
    }

    public record AdminUserResponse(
            Long id,
            String account,
            String nickname,
            String role,
            String status,
            OffsetDateTime createdAt,
            OffsetDateTime lastLoginAt
    ) {
        static AdminUserResponse from(UserEntity user) {
            return new AdminUserResponse(
                    user.getId(),
                    user.getAccount(),
                    user.getNickname(),
                    user.getRole(),
                    user.getStatus(),
                    user.getCreatedAt(),
                    user.getLastLoginAt()
            );
        }
    }

    public record CreateUserRequest(
            String account,
            String nickname,
            String role
    ) {
    }

    public record UpdateNicknameRequest(String nickname) {
    }

    public record UpdateStatusRequest(String status) {
    }

    public record ResetPasswordResponse(String defaultPassword) {
    }
}
