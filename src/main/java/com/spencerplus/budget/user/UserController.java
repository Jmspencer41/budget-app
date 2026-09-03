package com.spencerplus.budget.user;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        User user = userService.createUser(
            request.firstName(), request.lastName(), request.email(), request.password(), request.birthday()
        );
        return UserResponse.fromEntity(user);
    }
}
