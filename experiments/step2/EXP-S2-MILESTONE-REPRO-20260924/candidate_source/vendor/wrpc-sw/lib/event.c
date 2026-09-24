/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <stdint.h>
#include <stddef.h>

#include "board.h"
#include "event.h"

// fixme: make configurable through BSPs/KConfig
#define MAX_EVENTS_PER_QUEUE 8
#define MAX_EVENT_HANDLERS 8

struct event_queue {
    uint8_t data[MAX_EVENTS_PER_QUEUE];
    uint8_t head, tail, count, size;
};

struct event_handler 
{
    struct event_queue queue;
    int enabled;
    int event_mask;
    void (*handler)(int event);
};

static struct event_handler handlers[MAX_EVENT_HANDLERS];
static int event_handler_count = 0;

static inline void queue_put( struct event_queue* buf, int c )
{
    if (buf->count >= buf->size)
		return;

    buf->data[buf->head] = c;
	buf->head++;
    buf->count++;

	if (buf->head >= buf->size)
		buf->head = 0;
}


static inline int queue_get( struct event_queue* buf )
{
    int rv;

    if( !buf->count )
        return -1;

    rv = buf->data[buf->tail];

    buf->tail++;
    if (buf->tail >= buf->size)
		buf->tail = 0;
    buf->count--;

    return rv;
}

static inline int queue_init( struct event_queue *buf )
{
    buf->head = buf->tail = buf->count = 0;
    buf->size = MAX_EVENTS_PER_QUEUE;
    return 0;
}

static inline int queue_full(struct event_queue *buf)
{
    return buf->size == buf->count;
}

static inline void queue_purge(struct event_queue *buf)
{
    buf->head = buf->tail = buf->count = 0;
}

int event_handler_register( int mask, int enable, void (*func)(int) )
{
    if( event_handler_count >= MAX_EVENT_HANDLERS )
        return -1;

    int rv = event_handler_count;
    struct event_handler *eh = &handlers[event_handler_count];

    event_handler_count++;
    eh->enabled = enable;
    eh->event_mask = mask;
    eh->handler = func;

    queue_init(&eh->queue);
    return rv;
}

int event_handler_enable( int id, int enable )
{
    struct event_handler *eh = &handlers[id];
    eh->enabled = enable;
    return 0;
}

int event_post( int event )
{
    int i;
    if (!BOARD_USE_EVENTS)
        return 0;
    for(i = 0; i < event_handler_count; i++ )
    {
        struct event_handler *eh = &handlers[i];
        if (!eh->enabled || (eh->event_mask & (1 << event)) == 0 )
            continue;

        queue_put(&eh->queue, event);
    }
    return 0;
}

int event_poll( int handler )
{
    struct event_handler *eh = &handlers[handler];

    if (!eh->enabled)
        return 0;

    if( eh->queue.count == 0 )
        return 0;

    return queue_get( &eh->queue );
}

void events_init(void)
{
    int i;

    event_handler_count = 0;

    for(i=0;i<MAX_EVENT_HANDLERS;i++)
        handlers[i].enabled = 0;
}

void events_dispatch(void)
{
    int i;

    for(i = 0; i < event_handler_count; i++ )
    {
        struct event_handler *eh = &handlers[i];

        if( !eh->enabled )
            continue;
        if( eh->queue.count == 0 )
            continue;
        if( eh->handler )
            eh->handler( queue_get( &eh->queue ));
    }
}

int event_listener_create( void )
{
    return event_handler_register( -1, 1, NULL );
}
