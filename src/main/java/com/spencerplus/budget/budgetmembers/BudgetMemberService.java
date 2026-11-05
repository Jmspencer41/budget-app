package com.spencerplus.budget.budgetmembers;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.dao.DataIntegrityViolationException;
import com.spencerplus.budget.budget.BudgetRepository;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.user.User;
import com.spencerplus.budget.user.UserRepository;

@Service
public class BudgetMemberService {
	
	private final BudgetMemberRepository budgetMemberRepository;
	private final UserRepository userRepository;
	private final BudgetRepository budgetRepository;
	
	public BudgetMemberService(BudgetMemberRepository budgetMemberRepository, UserRepository userRepository, BudgetRepository budgetRepository) {
		this.budgetMemberRepository = budgetMemberRepository;
		this.userRepository = userRepository;
		this.budgetRepository = budgetRepository;
	}
	
	public BudgetMember createBudgetMember(UUID budgetId, UUID userId, Role role) {
		if (role == Role.OWNER) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Owner is set when the budget is created and cannot be added as a member");
		}
		if (!budgetRepository.existsById(budgetId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Budget not found");
		}
		if (!userRepository.existsById(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found");
		}
		if (budgetMemberRepository.findByBudgetIdAndUserId(budgetId, userId).isPresent()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "User is already a member of this budget");
		}

		BudgetMember budgetMember = new BudgetMember();
		budgetMember.setBudgetId(budgetId);
		budgetMember.setUserId(userId);
		budgetMember.setRole(role);
		try {
			return budgetMemberRepository.saveAndFlush(budgetMember);
		} catch (DataIntegrityViolationException e) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "User is already a member of this budget");
		}
	}
	
	public void deleteBudgetMember(UUID memberId) {
	    BudgetMember member = budgetMemberRepository.findById(memberId)
	        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Member not found"));
	    if (member.getRole() == Role.OWNER) {
	        throw new ResponseStatusException(HttpStatus.CONFLICT, "The owner cannot be removed from a budget");
	    }
	    budgetMemberRepository.delete(member);
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
