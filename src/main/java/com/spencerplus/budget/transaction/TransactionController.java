package com.spencerplus.budget.transaction;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/transactions")
public class TransactionController {
	
	private final TransactionService transactionService;
	
	public TransactionController(TransactionService transactionService) {
		this.transactionService = transactionService;
	}
	
	@PostMapping
	public TransactionResponse createTransaction(@Valid @RequestBody CreateTransactionRequest request) {
		Transaction transaction = transactionService.createTransaction(
				request.categoryId(), 
				request.userId(), 
				request.merchant(), 
				request.description(), 
				request.amountCents(), 
				request.transactionDate()
				);
		return TransactionResponse.fromEntity(transaction);
				
	}
	
	@GetMapping("/category/{categoryId}")
	public List<TransactionResponse> getTransactionsForCategory(@PathVariable UUID categoryId) {
		List<Transaction> transactions = transactionService.getTransactionForCategory(categoryId);
		List<TransactionResponse> response = new ArrayList<>();
		
		for (Transaction transaction : transactions) {
			response.add(TransactionResponse.fromEntity(transaction));
		}
		return response;
		
	}
	
}
