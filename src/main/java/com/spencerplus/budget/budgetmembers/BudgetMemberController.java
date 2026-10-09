package com.spencerplus.budget.budgetmembers;

import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.spencerplus.budget.budgetmembers.BudgetMemberService.BudgetMemberView;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/budgetmembers")
public class BudgetMemberController {

	private final BudgetMemberService budgetMemberService;
	
	public BudgetMemberController(BudgetMemberService budgetMemberService) {
		this.budgetMemberService = budgetMemberService;
	}
	
	@GetMapping("/budget/{budgetId}")
	public List<BudgetMemberView> listForBudget(@PathVariable UUID budgetId) {
		return budgetMemberService.listForBudget(budgetId);
	}

	@PostMapping
	public BudgetMemberResponse createBudgetMember(@Valid @RequestBody CreateBudgetMemberRequest request) {
		BudgetMember budgetMember = budgetMemberService.createBudgetMember(request.budgetId(), request.userId(), request.role());
		return BudgetMemberResponse.fromEntity(budgetMember);
	}

}
