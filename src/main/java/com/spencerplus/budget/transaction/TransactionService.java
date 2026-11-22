package com.spencerplus.budget.transaction;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.config.AccessService;

@Service
public class TransactionService {

	private final TransactionRepository transactionRepository;
	private final AccessService accessService;
	
	public TransactionService(TransactionRepository transactionRepository, AccessService accessService) {
		this.transactionRepository = transactionRepository;
		this.accessService = accessService;
	}
	
	public Transaction createTransaction(UUID categoryId, UUID userId, String merchant, String description, long amountCents, LocalDate transactionDate) {
		accessService.requireCategoryEditor(categoryId);
		Transaction transaction = new Transaction();
		transaction.setUserId(accessService.currentUserId());
		transaction.setCategoryId(categoryId);
		transaction.setMerchant(merchant);
		transaction.setDescription(description);
		transaction.setAmountCents(amountCents);
		transaction.setTransactionDate(transactionDate);
		return transactionRepository.save(transaction);
	}
	
	public void deleteTransaction(UUID transactionId) {
		Transaction transaction = transactionRepository.findById(transactionId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found"));
		accessService.requireCategoryEditor(transaction.getCategoryId());
		transactionRepository.deleteById(transactionId);
	}
	
	public List<Transaction> getTransactionForCategory(UUID categoryId, LocalDate from, LocalDate to) {
		accessService.requireCategoryMember(categoryId);
		if (from != null && to != null) {
			if (from.isAfter(to)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "'from' must be on or before 'to'");
			}
			return transactionRepository.findByCategoryIdAndTransactionDateBetween(categoryId, from, to);
		}
		if (from != null) {
			return transactionRepository.findByCategoryIdAndTransactionDateGreaterThanEqual(categoryId, from);
		}
		if (to != null) { 
			return transactionRepository.findByCategoryIdAndTransactionDateLessThanEqual(categoryId, to); 
		}
		return transactionRepository.findByCategoryId(categoryId);
	}
	
}
