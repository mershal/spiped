#include <signal.h>
#include <stdlib.h>

#include "events.h"
#include "warnp.h"

#include "graceful_shutdown.h"

struct graceful_shutdown_cookie {
	void (* begin_shutdown)(void *);
	void * caller_cookie;
};

static volatile sig_atomic_t should_shutdown = 0;
static void * graceful_shutdown_timer_cookie = NULL;

/* Signal handler for SIGTERM to perform a graceful shutdown. */
static void
graceful_shutdown_handler(int signo)
{

	(void)signo; /* UNUSED */
	should_shutdown = 1;
}

/* Requests a graceful shutdown of the caller via the cookie info. */
static int
graceful_shutdown(void * cookie)
{
	struct graceful_shutdown_cookie * G = cookie;

	/* This timer has expired. */
	graceful_shutdown_timer_cookie = NULL;

	/* Use the callback function, or schedule another check in 1 second. */
	if (should_shutdown)
		G->begin_shutdown(G->caller_cookie);
	else
		graceful_shutdown_timer_cookie = events_timer_register_double(
		    graceful_shutdown, G, 1.0);

	/* Success! */
	return (0);
}

/**
 * graceful_shutdown_register(callback, caller_cookie):
 * Initializes an event which checks for SIGTERM every 1.0 seconds; if
 * detected, it calls the ${callback} function and passes it the ${cookie}.
 */
void *
graceful_shutdown_register(void (* begin_shutdown)(void *),
    void * caller_cookie)
{
	struct graceful_shutdown_cookie * G;

	/* Bake a cookie. */
	if ((G = malloc(sizeof(struct graceful_shutdown_cookie))) == NULL)
		goto err0;

	G->begin_shutdown = begin_shutdown;
	G->caller_cookie = caller_cookie;

	/* Start signal handler. */
	if (signal(SIGTERM, graceful_shutdown_handler) == SIG_ERR) {
		warnp("signal");
		goto err1;
	}

	/* Check periodically whether a signal was received. */
	graceful_shutdown_timer_cookie = events_timer_register_double(
	    graceful_shutdown, G, 1.0);

	/* Success ! */
	return (G);

err1:
	free(G);
err0:
	/* Failure! */
	return (NULL);
}

/**
 * graceful_shutdown_shutdown(cookie):
 * Stop and free the graceful shutdown timer.
 */
void
graceful_shutdown_shutdown(void * cookie)
{

	if (graceful_shutdown_timer_cookie != NULL)
		events_timer_cancel(graceful_shutdown_timer_cookie);
	free(cookie);
}
