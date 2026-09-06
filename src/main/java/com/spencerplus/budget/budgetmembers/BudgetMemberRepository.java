package com.spencerplus.budget.budgetmembers;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BudgetMemberRepository extends JpaRepository<BudgetMember, UUID> {
	List<BudgetMember> findByUserId(UUID userId);
    List<BudgetMember> findByBudgetId(UUID budgetId);
    Optional<BudgetMember> findByBudgetIdAndUserId(UUID budgetId, UUID userId);
}
