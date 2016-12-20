#ifndef GRACEFUL_SHUTDOWN_H
#define GRACEFUL_SHUTDOWN_H

/**
 * graceful_shutdown_register(callback, caller_cookie):
 * Initializes an event which checks for SIGTERM every 1.0 seconds; if
 * detected, it calls the ${callback} function and passes it the
 * ${caller_cookie}.
 */
void * graceful_shutdown_register(void (*)(void *), void *);

/**
 * graceful_shutdown_shutdown(cookie):
 * Stop and free the graceful shutdown timer.
 */
void graceful_shutdown_shutdown(void *);

#endif
