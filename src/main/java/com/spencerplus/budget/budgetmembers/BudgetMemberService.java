package com.spencerplus.budget.budgetmembers;

import java.util.UUID;
import org.springframework.stereotype.Service;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;

@Service
public class BudgetMemberService {
	
	private final BudgetMemberRepository budgetMemberRepository;
	
	public BudgetMemberService(BudgetMemberRepository budgetMemberRepository) {
		this.budgetMemberRepository = budgetMemberRepository;
	}
	
	public BudgetMember createBudgetMember(UUID budgetId, UUID userId, Role role) {
		BudgetMember budgetMember = new BudgetMember();
		budgetMember.setBudgetId(budgetId);
		budgetMember.setUserId(userId);
		budgetMember.setRole(role);
		return budgetMemberRepository.save(budgetMember);
	}
}
