package com.spencerplus.budget.config;

import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.budgetmembers.BudgetMember;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.budgetmembers.BudgetMemberRepository;
import com.spencerplus.budget.category.Category;
import com.spencerplus.budget.category.CategoryRepository;
import com.spencerplus.budget.incomesource.IncomeSource;
import com.spencerplus.budget.incomesource.IncomeSourceRepository;

@Service
public class AccessService {

    private final BudgetMemberRepository budgetMemberRepository;
    private final CategoryRepository categoryRepository;
    private final IncomeSourceRepository incomeSourceRepository;

    public AccessService(
            BudgetMemberRepository budgetMemberRepository,
            CategoryRepository categoryRepository,
            IncomeSourceRepository incomeSourceRepository) {
        this.budgetMemberRepository = budgetMemberRepository;
        this.categoryRepository = categoryRepository;
        this.incomeSourceRepository = incomeSourceRepository;
    }

    public UUID currentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UUID userId)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sign in required");
        }
        return userId;
    }

    public void requireSelf(UUID userId) {
        if (!currentUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You can only access your own account");
        }
    }

    public BudgetMember requireMember(UUID budgetId) {
        UUID userId = currentUserId();
        return budgetMemberRepository.findByBudgetIdAndUserId(budgetId, userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "You are not a member of this budget"));
    }

    public void requireEditor(UUID budgetId) {
        BudgetMember member = requireMember(budgetId);
        if (member.getRole() == Role.VIEWER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Viewers cannot change this budget");
        }
    }

    public void requireOwner(UUID budgetId) {
        BudgetMember member = requireMember(budgetId);
        if (member.getRole() != Role.OWNER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only the owner can do that");
        }
    }

    public Category requireCategoryMember(UUID categoryId) {
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found"));
        requireMember(category.getBudgetId());
        return category;
    }

    public Category requireCategoryEditor(UUID categoryId) {
        Category category = categoryRepository.findById(categoryId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found"));
        requireEditor(category.getBudgetId());
        return category;
    }

    public IncomeSource requireIncomeMember(UUID incomeSourceId) {
        IncomeSource source = incomeSourceRepository.findById(incomeSourceId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Income source not found"));
        requireMember(source.getBudgetId());
        return source;
    }

    public IncomeSource requireIncomeEditor(UUID incomeSourceId) {
        IncomeSource source = incomeSourceRepository.findById(incomeSourceId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Income source not found"));
        requireEditor(source.getBudgetId());
        return source;
    }
}
