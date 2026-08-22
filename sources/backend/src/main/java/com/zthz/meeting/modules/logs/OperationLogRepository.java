package com.zthz.meeting.modules.logs;

import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OperationLogRepository extends JpaRepository<OperationLogEntity, Long> {
    @EntityGraph(attributePaths = "operator")
    List<OperationLogEntity> findTop100ByOrderByCreatedAtDesc();
}

