package com.zthz.meeting.modules.logs;

import com.zthz.meeting.common.ApiResponse;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/operation-logs")
public class AdminOperationLogController {

    private final OperationLogRepository operationLogRepository;

    public AdminOperationLogController(OperationLogRepository operationLogRepository) {
        this.operationLogRepository = operationLogRepository;
    }

    @GetMapping
    public ApiResponse<List<OperationLogResponse>> listLogs() {
        return ApiResponse.ok(operationLogRepository.findTop100ByOrderByCreatedAtDesc().stream()
                .map(OperationLogResponse::from)
                .toList());
    }

    public record OperationLogResponse(
            Long id,
            String operatorAccount,
            String action,
            String targetType,
            Long targetId,
            String clientIp,
            String userAgent,
            String detail,
            OffsetDateTime createdAt
    ) {
        static OperationLogResponse from(OperationLogEntity entity) {
            return new OperationLogResponse(
                    entity.getId(),
                    entity.getOperator() == null ? null : entity.getOperator().getAccount(),
                    entity.getAction(),
                    entity.getTargetType(),
                    entity.getTargetId(),
                    entity.getClientIp(),
                    entity.getUserAgent(),
                    entity.getDetail(),
                    entity.getCreatedAt()
            );
        }
    }
}

