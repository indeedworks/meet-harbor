package com.zthz.meeting.modules.logs;

import com.zthz.meeting.modules.admin.users.UserEntity;
import com.zthz.meeting.modules.admin.users.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OperationLogService {

    private final OperationLogRepository operationLogRepository;
    private final UserRepository userRepository;

    public OperationLogService(OperationLogRepository operationLogRepository, UserRepository userRepository) {
        this.operationLogRepository = operationLogRepository;
        this.userRepository = userRepository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String action, String targetType, Long targetId, String detail, HttpServletRequest request) {
        save(currentUser(), action, targetType, targetId, detail, request);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordAs(UserEntity operator, String action, String targetType, Long targetId, String detail, HttpServletRequest request) {
        save(operator, action, targetType, targetId, detail, request);
    }

    private void save(
            UserEntity operator,
            String action,
            String targetType,
            Long targetId,
            String detail,
            HttpServletRequest request
    ) {
        OperationLogEntity log = new OperationLogEntity();
        log.setOperator(operator);
        log.setAction(action);
        log.setTargetType(targetType);
        log.setTargetId(targetId);
        log.setClientIp(clientIp(request));
        log.setUserAgent(request == null ? null : request.getHeader("User-Agent"));
        log.setDetail(detail);
        log.setCreatedAt(OffsetDateTime.now());
        operationLogRepository.save(log);
    }

    private UserEntity currentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || authentication.getName() == null) {
            return null;
        }
        return userRepository.findByAccount(authentication.getName()).orElse(null);
    }

    private String clientIp(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
