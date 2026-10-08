package com.spencerplus.budget.incomesource;

import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/incomesources")
public class IncomeSourceController {
	
	private final IncomeSourceService incomeSourceService;
	
	public IncomeSourceController(IncomeSourceService incomeSourceService) {
		this.incomeSourceService = incomeSourceService;
	}
	
	@GetMapping("/budget/{budgetId}")
	public List<IncomeSourceResponse> listForBudget(@PathVariable UUID budgetId) {
		return incomeSourceService.listForBudget(budgetId).stream().map(IncomeSourceResponse::fromEntity).toList();
	}

	@PostMapping
	public IncomeSourceResponse createIncomeSource(@Valid @RequestBody CreateIncomeSourceRequest request) {
		IncomeSource incomeSource = incomeSourceService.createIncomeSource(
				request.userId(), request.budgetId(), request.name(), request.amountCents(), request.frequency(), request.autoGenerate(), request.nextPayDate()
				);
		return IncomeSourceResponse.fromEntity(incomeSource);
	}
}
