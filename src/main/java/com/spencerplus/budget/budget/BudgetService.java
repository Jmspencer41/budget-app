package com.spencerplus.budget.budget;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.spencerplus.budget.budgetmembers.BudgetMember;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.budgetmembers.BudgetMemberRepository;
import com.spencerplus.budget.category.Category;
import com.spencerplus.budget.category.CategoryRepository;
import com.spencerplus.budget.category.CategoryService;
import java.util.UUID;
import java.util.ArrayList;
import java.util.List;

@Service
public class BudgetService {
	
	private final BudgetRepository budgetRepository;
	private final CategoryRepository categoryRepository;
	private final CategoryService categoryService;
	private final BudgetMemberRepository budgetMemberRepository;
	
	public BudgetService(
			BudgetRepository budgetRepository,
			CategoryRepository categoryRepository,
			CategoryService categoryService,
			BudgetMemberRepository budgetMemberRepository) {
		this.budgetRepository = budgetRepository;
		this.categoryRepository = categoryRepository;
		this.categoryService = categoryService;
		this.budgetMemberRepository = budgetMemberRepository;
	}
	
	@Transactional
	public Budget createBudget(String title, UUID ownerId) {
		Budget budget = new Budget();
		budget.setTitle(title);
		budget.setOwnerId(ownerId);
		Budget saved = budgetRepository.save(budget);

		BudgetMember owner = new BudgetMember();
		owner.setBudgetId(saved.getId());
		owner.setUserId(ownerId);
		owner.setRole(Role.OWNER);
		budgetMemberRepository.save(owner);
		return saved;
	}

	  public List<Budget> listForUser(UUID userId) {
	      List<UUID> budgetIds = new ArrayList<>();
	      for (BudgetMember member : budgetMemberRepository.findByUserId(userId)) {
	          budgetIds.add(member.getBudgetId());
	      }
	      return budgetRepository.findAllById(budgetIds);
	  }

	public void deleteBudget(UUID budgetId) {
		budgetRepository.deleteById(budgetId);
	}
	
	public long getTotal(UUID budgetId) {
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long total = 0;
		for (Category category : categories) {
			total += category.getAmountCents();
		}
		
		return total;
	}
	
	public long getRemainingBalance(UUID budgetId) {
		
		List<Category> categories = categoryRepository.findByBudgetId(budgetId);
		
		long totalRemaining = 0;
		
		for (Category category : categories) {
			totalRemaining += categoryService.getRemainingAmount(category.getId());
		}
		
		return totalRemaining;
	}
}
