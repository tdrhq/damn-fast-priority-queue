# Damn Fast Priority Queue

A heap-based priority queue whose first and foremost priority is [**speed**](https://www.youtube.com/watch?v=AkagvXwDsYU).

Blame [@mfiano](https://github.com/mfiano/) for the existence of this library. He's the one who wanted a priority queue that's going to run as fast as possible in one of the hottest loops of his game engine ~~and then figured out that hey, he actually doesn't need a prio queue there~~.

## License

MIT.

## Description

* The queue enqueues objects along with their priorities.
  * The stored objects may be of arbitrary type.
  * The objects' priorities must be of type `(unsigned-byte 32)`.
* The queue is a minimum queue (i.e. smallest priorities are dequeued first).
* The queue is unbounded.
  * The queue's storage automatically expands (which reallocates the queue storage).
  * The queue's storage can be manually trimmed (which reallocates the queue storage).
* The queue does not preserve FIFO order for elements with the same priority.
* The queue is **not** thread-safe.
* The queue is **not** reentrant.

## Implementation details

* The queue internally uses two simple vectors: one for data, specialized on `t`, and another for priorities, specialized on `(unsigned-byte 32)`.
* The queue's storage has its initial size set to the extension factor.
* Each time the queue runs out of storage, the storage is reallocated via `adjust-array` and its size is expanded by the `extension-factor` value provided at queue instantiation.
* We assume that using simple vectors, calling `adjust-array` on them, and manually setting queue slots to the new vectors is faster than using adjustable vectors.

## Optimization settings

* The code uses structure classes in favor of standard classes.
* The code uses standard, `inline`-proclaimed functions in favor of generic functions.
* All functions are optimized for maximum `speed`.
* By default, the code retains the default values of `debug`, `safety`, `space`, and `compilation-speed` optimize qualities. To set them all to 0, pray to your favorite deity and push `:real-damn-fast-priority-queue` into `*features*` before compiling the system.

## Exports

All exported functions are proclaimed `inline` by default.

* **Classes**
  * `queue` - names the priority queue structure class.
* **Functions**
  * `(make-queue &optional extension-factor)` - make a priority queue with a given extension factor.
    * The extension factor value must be a positive integer between `2` and `256`.
    * The default extension factor is `2`.
  * `(enqueue queue object priority)` - enqueue an object.
  * `(dequeue queue)` - dequeue an object.
    * Secondary return value is true if the object was found and false if the queue was empty.
  * `(peek queue)` - peek at an object that is first to be dequeued.
    * Secondary return value is true if the object was found and false if the queue was empty.
  * `(size queue)` - get the current element count of the queue.
  * `(trim queue)` - trim the queue's storage by calling `adjust-array` on it with the current queue size.

## Tests

* Non-verbose test: `(asdf:test-system :damn-fast-priority-queue)` or `(asdf:load-system :damn-fast-priority-queue/test) (damn-fast-priority-queue/test:run)`
* Verbose test: `(asdf:load-system :damn-fast-priority-queue/test) (damn-fast-priority-queue/test:run t)`

## Performance tests

The file `damn-fast-priority-queue-perftest.lisp` contains a simple performance test with tweakable values:
* `+capacity+` - how many elements will be pushed into the queue,
* `+repeat-count+` - how many times the test will be repeated,
* `+pass-capacity-p+` - should the test pass the value of `+capacity+` into the queue?
  * Not all tested queue libraries support passing the initial capacity or extension factor as parameters when constructing the queue.

The performance test includes multiple priority queue/heap libraries available on Quicklisp, tested against three benchmarks:
* an array of unique numbers from `0` to `n`, in increasing order,
* an array of unique numbers from `0` to `n`, in decreasing order,
* an array of unique numbers from `0` to `n`, in shuffled order.

The listed timing does not include the time required to prepare the test vectors or to construct the priority queue object.

Please feel free to question, verify, and improve the code and results of this benchmark.

### 409600 elements, 10 repeats, capacity passed

| Library\Vector                    | :increasing | :decreasing | :shuffled |
|-----------------------------------|-------------|-------------|-----------|
| :pettomato-indexed-priority-queue | 4.323       | 5.943       | 6.463     |
| :priority-queue                   | 6.335       | 10.195      | 7.251     |
| :queues.priority-queue            | 7.663       | 7.295       | 13.539    |
| :pileup                           | 2.019       | 2.207       | 2.143     |
| :bodge-heap                       | 5.703       | 12.203      | 6.359     |
| :cl-heap                          | 9.483       | 10.471      | 28.119    |
| :heap                             | 9.491       | 12.167      | 9.287     |
| :minheap                          | 6.335       | 7.951       | 7.663     |
| :damn-fast-priority-queue         | **0.599**   | **0.719**   | **0.819** |

### 409600 elements, 10 repeats, capacity not passed

| Library\Vector                    | :increasing | :decreasing | :shuffled |
|-----------------------------------|-------------|-------------|-----------|
| :pettomato-indexed-priority-queue | 4.759       | 5.963       | 7.311     |
| :priority-queue                   | 6.339       | 10.067      | 7.427     |
| :queues.priority-queue            | 7.223       | 7.207       | 11.807    |
| :pileup                           | 1.851       | 2.187       | 2.111     |
| :bodge-heap                       | 5.423       | 12.403      | 8.051     |
| :cl-heap                          | 9.035       | 10.715      | 31.211    |
| :heap                             | 8.583       | 12.263      | 8.999     |
| :minheap                          | 5.523       | 7.789       | 11.335    |
| :damn-fast-priority-queue         | **0.575**   | **0.727**   | **0.931** |

### 4096 elements, 1000 repeats, capacity passed

| Library\Vector                    | :increasing | :decreasing | :shuffled |
|-----------------------------------|-------------|-------------|-----------|
| :pettomato-indexed-priority-queue | 2.567       | 3.599       | 2.887     |
| :priority-queue                   | 3.863       | 5.995       | 4.359     |
| :queues.priority-queue            | 5.491       | 4.963       | 5.231     |
| :pileup                           | 1.391       | 1.591       | 1.471     |
| :bodge-heap                       | 3.471       | 8.271       | 3.991     |
| :cl-heap                          | 6.467       | 10.795      | 13.807    |
| :heap                             | 5.187       | 8.339       | 5.587     |
| :minheap                          | 3.135       | 5.767       | 3.531     |
| :damn-fast-priority-queue         | **0.375**   | **0.455**   | **0.471** |

### 4096 elements, 1000 repeats, capacity not passed

| Library\Vector                    | :increasing | :decreasing | :shuffled |
|-----------------------------------|-------------|-------------|-----------|
| :pettomato-indexed-priority-queue | 2.555       | 3.607       | 2.943     |
| :priority-queue                   | 3.831       | 6.647       | 4.311     |
| :queues.priority-queue            | 4.855       | 6.579       | 5.231     |
| :pileup                           | 1.399       | 1.611       | 1.503     |
| :bodge-heap                       | 3.419       | 8.199       | 4.171     |
| :cl-heap                          | 6.479       | 8.527       | 13.967    |
| :heap                             | 5.243       | 7.539       | 5.619     |
| :minheap                          | 3.215       | 4.487       | 3.471     |
| :damn-fast-priority-queue         | **0.379**   | **0.467**   | **0.467** |
