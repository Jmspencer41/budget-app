package com.spencerplus.budget.transaction;

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
	
}

//id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//category_id UUID NOT NULL REFERENCES categories(id),
//user_id UUID NOT NULL REFERENCES users(id),
//merchant VARCHAR(255),
//description VARCHAR(255),
//amount_cents BIGINT NOT NULL,
//transaction_date DATE NOT NULL,
//created_at TIMESTAMP NOT NULL DEFAULT now()