package com.spencerplus.budget.user;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

	@Mock private UserRepository userRepository;
	@Mock private PasswordEncoder passwordEncoder;

	private UserService service;
	private final String email = "test@example.com";

	@BeforeEach
	void setUp() {
		service = new UserService(userRepository, passwordEncoder);
	}

	private HttpStatus statusOf(ResponseStatusException e) {
		return HttpStatus.valueOf(e.getStatusCode().value());
	}

	@Test
	void existingEmailIsConflict() {
		when(userRepository.findByEmail(email)).thenReturn(Optional.of(new User()));

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createUser("Test", "User", email, "secret", null));
		assertEquals(HttpStatus.CONFLICT, statusOf(e));
		verify(passwordEncoder, never()).encode(anyString()); // no wasted hashing
		verify(userRepository, never()).saveAndFlush(any());
	}

	@Test
	void constraintViolationOnSaveIsConflict() { // the race: check passed, but the insert hit the UNIQUE constraint
		when(userRepository.findByEmail(email)).thenReturn(Optional.empty());
		when(userRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("duplicate"));

		ResponseStatusException e = assertThrows(ResponseStatusException.class,
				() -> service.createUser("Test", "User", email, "secret", null));
		assertEquals(HttpStatus.CONFLICT, statusOf(e));
	}

	@Test
	void newUserIsSavedWithHashedPassword() {
		User saved = new User();
		when(userRepository.findByEmail(email)).thenReturn(Optional.empty());
		when(passwordEncoder.encode("secret")).thenReturn("hashed");
		when(userRepository.saveAndFlush(any())).thenReturn(saved);

		assertSame(saved, service.createUser("Test", "User", email, "secret", null));
		verify(passwordEncoder).encode("secret");
	}
}