package com.spencerplus.budget.budgetmembers;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/budgetmembers")
public class BudgetMemberController {

	private final BudgetMemberService budgetMemberService;
	
	public BudgetMemberController(BudgetMemberService budgetMemberService) {
		this.budgetMemberService = budgetMemberService;
	}
	
	@PostMapping
	public BudgetMemberResponse createBudgetMember(@Valid @RequestBody CreateBudgetMemberRequest request) {
		BudgetMember budgetMember = budgetMemberService.createBudgetMember(request.budgetId(), request.userId(), request.role());
		return BudgetMemberResponse.fromEntity(budgetMember);
	}

}
