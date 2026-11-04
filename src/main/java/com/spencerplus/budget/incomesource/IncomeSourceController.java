package com.spencerplus.budget.incomesource;

import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/incomesources")
public class IncomeSourceController {
	
	private final IncomeSourceService incomeSourceService;
	
	public IncomeSourceController(IncomeSourceService incomeSourceService) {
		this.incomeSourceService = incomeSourceService;
	}
	
	@GetMapping("/budget/{budgetId}")
	public List<IncomeSourceResponse> listForBudget(
			@PathVariable UUID budgetId,
			@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf) {
		if (asOf == null) {
			asOf = LocalDate.now(); // no date sent, so use the server's today
		}
		List<IncomeSource> incomeSources = incomeSourceService.listForBudget(budgetId);
		List<IncomeSourceResponse> responses = new ArrayList<>();
		for (IncomeSource incomeSource : incomeSources) {
			responses.add(incomeSourceService.toResponse(incomeSource, asOf));
		}
		return responses;
	}

	@PostMapping
	public IncomeSourceResponse createIncomeSource(@Valid @RequestBody CreateIncomeSourceRequest request) {
		IncomeSource incomeSource = incomeSourceService.createIncomeSource(
				request.userId(), request.budgetId(), request.name(), request.amountCents(), request.frequency(), request.autoGenerate(), request.anchorDate(), request.secondPayDay()
				);
		return incomeSourceService.toResponse(incomeSource, LocalDate.now());
	}
	
	@PutMapping("/{id}")
	public IncomeSourceResponse updateIncomeSource(@PathVariable UUID id, @Valid @RequestBody UpdateIncomeSourceRequest request) {
		IncomeSource incomeSource = incomeSourceService.updateIncomeSource(
				id, request.name(), request.amountCents(), request.frequency(), request.anchorDate(), request.secondPayDay()
				);
		return incomeSourceService.toResponse(incomeSource, LocalDate.now());
	}
	
	@DeleteMapping("/{id}")
	public void deleteIncomeSource(@PathVariable UUID id) {
	    incomeSourceService.deleteIncomeSource(id);
	}
}
