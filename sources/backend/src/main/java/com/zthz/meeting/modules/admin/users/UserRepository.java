package com.zthz.meeting.modules.admin.users;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<UserEntity, Long> {
    boolean existsByAccount(String account);

    Optional<UserEntity> findByAccount(String account);
}

