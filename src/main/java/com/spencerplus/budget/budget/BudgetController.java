package com.spencerplus.budget.budget;

import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/budgets")
public class BudgetController {

    private final BudgetService budgetService;

    public BudgetController(BudgetService budgetService) {
        this.budgetService = budgetService;
    }

    @GetMapping
    public List<BudgetResponse> listForOwner(@RequestParam UUID ownerId) {
        return budgetService.listForOwner(ownerId).stream().map(BudgetResponse::fromEntity).toList();
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
    
}