package worker

import (
	"event-service/internal/model"
	"event-service/internal/store"
	"log"
	"sync"
	"sync/atomic"
	"time"
)

const queueSize = 100

// Worker processes events asynchronously in the background
type Worker struct {
	queue           chan *model.Event
	store           *store.Store
	processingDelay time.Duration
	running         atomic.Bool
	done            chan struct{}
	stopped         chan struct{}
	stopOnce        sync.Once
}

// New creates a new background worker
func New(store *store.Store, processingDelayMs int) *Worker {
	return &Worker{
		queue:           make(chan *model.Event, queueSize),
		store:           store,
		processingDelay: time.Duration(processingDelayMs) * time.Millisecond,
		done:            make(chan struct{}),
		stopped:         make(chan struct{}),
	}
}

// Start begins processing events from the queue
func (w *Worker) Start() {
	w.running.Store(true)
	log.Printf("Worker started with processing delay: %v", w.processingDelay)

	go func() {
		defer close(w.stopped)
		for {
			select {
			case event := <-w.queue:
				w.processEvent(event)
			case <-w.done:
				log.Println("Worker shutting down")
				w.running.Store(false)
				// Drain events that were accepted before shutdown
				for {
					select {
					case event := <-w.queue:
						w.processEvent(event)
					default:
						return
					}
				}
			}
		}
	}()
}

// Stop gracefully stops the worker and waits until queued events are processed
// or the timeout elapses. It is safe to call more than once.
func (w *Worker) Stop(timeout time.Duration) {
	w.stopOnce.Do(func() {
		log.Println("Stopping worker...")
		close(w.done)
	})
	select {
	case <-w.stopped:
	case <-time.After(timeout):
		log.Println("Timed out waiting for worker to drain")
	}
}

// Enqueue adds an event to the processing queue without blocking.
// It returns false if the queue is full or the worker is stopping.
func (w *Worker) Enqueue(event *model.Event) bool {
	if !w.running.Load() {
		return false
	}
	select {
	case w.queue <- event:
		return true
	default:
		return false
	}
}

// IsRunning returns whether the worker is currently running
func (w *Worker) IsRunning() bool {
	return w.running.Load()
}

// processEvent simulates event processing with a configurable delay
func (w *Worker) processEvent(event *model.Event) {
	log.Printf("Processing event: %s", event.EventID)

	// Simulate work
	time.Sleep(w.processingDelay)

	w.store.MarkProcessed(event.EventID)
	log.Printf("Event processed: %s", event.EventID)
}
