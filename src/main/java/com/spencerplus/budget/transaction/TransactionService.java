package com.spencerplus.budget.transaction;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class TransactionService {

	private final TransactionRepository transactionRepository;
	
	public TransactionService(TransactionRepository transactionRepository) {
		this.transactionRepository = transactionRepository;
	}
	
	public Transaction createTransaction(UUID categoryId, UUID userId, String merchant, String description, long amountCents, LocalDate transactionDate) {
		Transaction transaction = new Transaction();
		transaction.setCategoryId(categoryId);
		transaction.setUserId(userId);
		transaction.setMerchant(merchant);
		transaction.setDescription(description);
		transaction.setAmountCents(amountCents);
		transaction.setTransactionDate(transactionDate);
		return transactionRepository.save(transaction);
	}
	
	public void deleteTransaction(UUID transactionId) {
	    if (!transactionRepository.existsById(transactionId)) {
	        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found");
	    }
	    transactionRepository.deleteById(transactionId);
	}
	
	public List<Transaction> getTransactionForCategory(UUID categoryId) {
		return transactionRepository.findByCategoryId(categoryId);
	}
	
}
