package com.zthz.meeting.modules.admin.users;

import java.time.OffsetDateTime;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@Order(0)
@ConditionalOnProperty(name = "app.bootstrap.admin-enabled", havingValue = "true")
public class DefaultAdminInitializer implements ApplicationRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final String adminAccount;
    private final String adminPassword;

    public DefaultAdminInitializer(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            @Value("${app.bootstrap.admin-account}") String adminAccount,
            @Value("${app.bootstrap.admin-password}") String adminPassword
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.adminAccount = adminAccount;
        this.adminPassword = adminPassword;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (userRepository.existsByAccount(adminAccount)) {
            return;
        }

        OffsetDateTime now = OffsetDateTime.now();
        UserEntity admin = new UserEntity();
        admin.setAccount(adminAccount);
        admin.setNickname("系统管理员");
        admin.setPasswordHash(passwordEncoder.encode(adminPassword));
        admin.setRole("ADMIN");
        admin.setStatus("ENABLED");
        admin.setCreatedAt(now);
        admin.setUpdatedAt(now);
        userRepository.save(admin);
    }
}
