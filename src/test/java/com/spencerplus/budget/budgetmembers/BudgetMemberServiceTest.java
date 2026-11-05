package com.spencerplus.budget.budgetmembers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.budget.BudgetRepository;
import com.spencerplus.budget.budgetmembers.BudgetMember.Role;
import com.spencerplus.budget.user.UserRepository;

@ExtendWith(MockitoExtension.class)
class BudgetMemberServiceTest {

	@Mock private BudgetMemberRepository budgetMemberRepository;
	@Mock private UserRepository userRepository;
	@Mock private BudgetRepository budgetRepository;

	private BudgetMemberService service;
	private final UUID budgetId = UUID.randomUUID();
	private final UUID userId = UUID.randomUUID();

	@BeforeEach
	void setUp() {
		service = new BudgetMemberService(budgetMemberRepository, userRepository, budgetRepository);
	}

	private HttpStatus statusOf(ResponseStatusException e) {
		return HttpStatus.valueOf(e.getStatusCode().value());
	}

	@Test
	void ownerRoleIsRejected() {
		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createBudgetMember(budgetId, userId, Role.OWNER));
		assertEquals(HttpStatus.BAD_REQUEST, statusOf(e));
		verify(budgetMemberRepository, never()).saveAndFlush(any());
	}

	@Test
	void missingBudgetIsNotFound() {
		when(budgetRepository.existsById(budgetId)).thenReturn(false);

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createBudgetMember(budgetId, userId, Role.EDITOR));
		assertEquals(HttpStatus.NOT_FOUND, statusOf(e));
		verify(budgetMemberRepository, never()).saveAndFlush(any());
	}

	@Test
	void missingUserIsNotFound() {
		when(budgetRepository.existsById(budgetId)).thenReturn(true);
		when(userRepository.existsById(userId)).thenReturn(false);

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createBudgetMember(budgetId, userId, Role.EDITOR));
		assertEquals(HttpStatus.NOT_FOUND, statusOf(e));
		verify(budgetMemberRepository, never()).saveAndFlush(any());
	}

	@Test
	void existingMemberIsConflict() {
		when(budgetRepository.existsById(budgetId)).thenReturn(true);
		when(userRepository.existsById(userId)).thenReturn(true);
		when(budgetMemberRepository.findByBudgetIdAndUserId(budgetId, userId)).thenReturn(Optional.of(new BudgetMember()));

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createBudgetMember(budgetId, userId, Role.EDITOR));
		assertEquals(HttpStatus.CONFLICT, statusOf(e));
		verify(budgetMemberRepository, never()).saveAndFlush(any());
	}

	@Test
	void constraintViolationOnSaveIsConflict() { // the race: check passed, but the insert hit the UNIQUE constraint
		when(budgetRepository.existsById(budgetId)).thenReturn(true);
		when(userRepository.existsById(userId)).thenReturn(true);
		when(budgetMemberRepository.findByBudgetIdAndUserId(budgetId, userId)).thenReturn(Optional.empty());
		when(budgetMemberRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("duplicate"));

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createBudgetMember(budgetId, userId, Role.EDITOR));
		assertEquals(HttpStatus.CONFLICT, statusOf(e));
	}

	@Test
	void validMemberIsSaved() {
		BudgetMember saved = new BudgetMember();
		when(budgetRepository.existsById(budgetId)).thenReturn(true);
		when(userRepository.existsById(userId)).thenReturn(true);
		when(budgetMemberRepository.findByBudgetIdAndUserId(budgetId, userId)).thenReturn(Optional.empty());
		when(budgetMemberRepository.saveAndFlush(any())).thenReturn(saved);

		assertSame(saved, service.createBudgetMember(budgetId, userId, Role.EDITOR));
	}
}