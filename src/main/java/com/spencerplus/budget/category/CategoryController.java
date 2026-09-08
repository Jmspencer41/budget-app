package com.spencerplus.budget.category;

import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {

	private final CategoryService categoryService;
	
	public CategoryController(CategoryService categoryService) {
		this.categoryService = categoryService;
	}
	
	@PostMapping 
	public CategoryResponse createCategory(@Valid @RequestBody CreateCategoryRequest request) {
		Category category = categoryService.createCategory(
				request.budgetId(), 
				request.name(), 
				request.categoryType(), 
				request.frequency(), 
				request.amountCents()
				);
		return CategoryResponse.fromEntity(category);
	}
	
	@GetMapping("/{id}/remaining")
	public long getRemainingAmount(@PathVariable UUID id) {
	    return categoryService.getRemainingAmount(id);
	}
	
}
