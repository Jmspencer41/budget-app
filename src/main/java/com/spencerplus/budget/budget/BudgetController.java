package com.spencerplus.budget.budget;

import jakarta.validation.Valid;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/budgets")
public class BudgetController {

    private final BudgetService budgetService;

    public BudgetController(BudgetService budgetService) {
        this.budgetService = budgetService;
    }

    @GetMapping
    public List<BudgetResponse> listForUser(@RequestParam UUID userId) {
        List<BudgetResponse> response = new ArrayList<>();
        for (Budget budget : budgetService.listForUser(userId)) {
            response.add(BudgetResponse.fromEntity(budget));
        }
        return response;
    }

    @DeleteMapping("/{id}")
    public void deleteBudget(@PathVariable UUID id) {
        budgetService.deleteBudget(id);
    }

    @PostMapping
    public BudgetResponse createBudget(@Valid @RequestBody CreateBudgetRequest request) {
        Budget budget = budgetService.createBudget(
            request.title(), request.ownerId()
        	);
        return BudgetResponse.fromEntity(budget);
    }
    
    @GetMapping("{id}/total")
    public long getTotal(@PathVariable UUID id) {
    	return budgetService.getTotal(id);
    }
    
    @GetMapping("{id}/remaining")
    public long getRemainingBalance(@PathVariable UUID id) {
    	return budgetService.getRemainingBalance(id);
    }
    
    @GetMapping("/{id}/income")
    public BudgetIncomeResponse getIncome(
    		@PathVariable UUID id,
    		@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf) {
    	if (asOf == null) {
    		asOf = LocalDate.now(); // no date sent, so use the server's today
    	}
    	return budgetService.getIncome(id, asOf);
    }
    
}