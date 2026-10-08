package com.spencerplus.budget.budgetmembers;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.user.User;
import com.spencerplus.budget.user.UserRepository;

@Service
public class BudgetMemberService {
	
	private final BudgetMemberRepository budgetMemberRepository;
	private final UserRepository userRepository;
	
	public BudgetMemberService(BudgetMemberRepository budgetMemberRepository, UserRepository userRepository) {
		this.budgetMemberRepository = budgetMemberRepository;
		this.userRepository = userRepository;
	}
	
	public BudgetMember createBudgetMember(UUID budgetId, UUID userId, Role role) {
		BudgetMember budgetMember = new BudgetMember();
		budgetMember.setBudgetId(budgetId);
		budgetMember.setUserId(userId);
		budgetMember.setRole(role);
		return budgetMemberRepository.save(budgetMember);
	}

	public List<BudgetMemberView> listForBudget(UUID budgetId) {
		List<BudgetMemberView> views = new ArrayList<>();
		for (BudgetMember member : budgetMemberRepository.findByBudgetId(budgetId)) {
			User user = userRepository.findById(member.getUserId()).orElse(null);
			String name = user == null ? "Member" : (user.getFirstName() + " " + user.getLastName()).trim();
			views.add(new BudgetMemberView(
					member.getId(), member.getBudgetId(), member.getUserId(), name, member.getRole()));
		}
		return views;
	}

	public record BudgetMemberView(UUID id, UUID budgetId, UUID userId, String name, Role role) {}
}
