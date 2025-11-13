const std = @import("std");
const testing = std.testing;
const collections = @import("ziro-collections");
const Queue = collections.Queue;

test "Queue: basic enqueue and dequeue" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), queue.size());

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);

    try testing.expectEqual(@as(usize, 3), queue.size());
    try testing.expect(!queue.isEmpty());

    try testing.expectEqual(@as(i32, 10), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 20), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 30), queue.dequeue().?);

    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(?i32, null), queue.dequeue());
}

test "Queue: peek operation" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try testing.expectEqual(@as(?i32, null), queue.peek());

    try queue.enqueue(100);
    try testing.expectEqual(@as(i32, 100), queue.peek().?);
    try testing.expectEqual(@as(usize, 1), queue.size());

    try queue.enqueue(200);
    try testing.expectEqual(@as(i32, 100), queue.peek().?);
    try testing.expectEqual(@as(usize, 2), queue.size());

    _ = queue.dequeue();
    try testing.expectEqual(@as(i32, 200), queue.peek().?);
}

test "Queue: clear operation" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    try testing.expectEqual(@as(usize, 3), queue.size());

    queue.clear();

    try testing.expect(queue.isEmpty());
    try testing.expectEqual(@as(usize, 0), queue.size());
    try testing.expectEqual(@as(?i32, null), queue.dequeue());
}

test "Queue: growth and capacity" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    // Add more items than initial capacity
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try queue.enqueue(i);
    }

    try testing.expectEqual(@as(usize, 100), queue.size());

    // Verify FIFO order
    i = 0;
    while (i < 100) : (i += 1) {
        try testing.expectEqual(i, queue.dequeue().?);
    }

    try testing.expect(queue.isEmpty());
}

test "Queue: circular buffer behavior" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    // Fill, partially empty, and refill to test circular wrapping
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    _ = queue.dequeue();
    _ = queue.dequeue();

    try queue.enqueue(4);
    try queue.enqueue(5);
    try queue.enqueue(6);

    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 4), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 5), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 6), queue.dequeue().?);
    try testing.expect(queue.isEmpty());
}

test "Queue: with strings" {
    var queue = Queue([]const u8).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue("first");
    try queue.enqueue("second");
    try queue.enqueue("third");

    try testing.expectEqualStrings("first", queue.dequeue().?);
    try testing.expectEqualStrings("second", queue.dequeue().?);
    try testing.expectEqualStrings("third", queue.dequeue().?);
}

test "Queue: with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    var queue = Queue(Point).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(.{ .x = 1, .y = 2 });
    try queue.enqueue(.{ .x = 3, .y = 4 });

    const p1 = queue.dequeue().?;
    try testing.expectEqual(@as(i32, 1), p1.x);
    try testing.expectEqual(@as(i32, 2), p1.y);

    const p2 = queue.dequeue().?;
    try testing.expectEqual(@as(i32, 3), p2.x);
    try testing.expectEqual(@as(i32, 4), p2.y);
}

test "Queue: stress test" {
    var queue = Queue(usize).init(testing.allocator);
    defer queue.deinit();

    const iterations = 1000;

    // Enqueue many items
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try queue.enqueue(i);
    }

    try testing.expectEqual(@as(usize, iterations), queue.size());

    // Dequeue and verify all items
    i = 0;
    while (i < iterations) : (i += 1) {
        const value = queue.dequeue().?;
        try testing.expectEqual(i, value);
    }

    try testing.expect(queue.isEmpty());
}

test "Queue: onHold basic functionality" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);

    // Put first item on hold
    try testing.expect(try queue.onHold());
    try testing.expect(queue.isOnHold());

    // Dequeue should skip first item and return second
    try testing.expectEqual(@as(i32, 20), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 2), queue.size());

    // First item should still be there
    try testing.expectEqual(@as(i32, 10), queue.peek().?);

    // Dequeue again should return third item
    try testing.expectEqual(@as(i32, 30), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 1), queue.size());

    // Release hold and dequeue the first item
    try testing.expect(queue.releaseHold());
    try testing.expect(!queue.isOnHold());
    try testing.expectEqual(@as(i32, 10), queue.dequeue().?);
    try testing.expect(queue.isEmpty());
}

test "Queue: onHold with single item" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(100);

    // Put the only item on hold
    try testing.expect(try queue.onHold());

    // Dequeue should return null since only item is on hold
    try testing.expectEqual(@as(?i32, null), queue.dequeue());
    try testing.expectEqual(@as(usize, 1), queue.size());

    // Release hold and dequeue
    try testing.expect(queue.releaseHold());
    try testing.expectEqual(@as(i32, 100), queue.dequeue().?);
    try testing.expect(queue.isEmpty());
}

test "Queue: onHold on empty queue" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    // Cannot put hold on empty queue
    try testing.expect(!(try queue.onHold()));
    try testing.expect(!queue.isOnHold());
}

test "Queue: releaseHold and normal dequeue" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    // Put on hold then release immediately
    try testing.expect(try queue.onHold());
    try testing.expect(queue.releaseHold());

    // Should dequeue normally
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
}

test "Queue: clear resets hold state" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(10);
    try testing.expect(try queue.onHold());
    try testing.expect(queue.isOnHold());

    queue.clear();

    try testing.expect(!queue.isOnHold());
    try testing.expect(queue.isEmpty());
}

test "Queue: multiple hold and release cycles" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    try queue.enqueue(4);

    // First cycle: hold and dequeue second
    try testing.expect(try queue.onHold());
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);

    // Release and dequeue first
    try testing.expect(queue.releaseHold());
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);

    // Second cycle: hold and dequeue second again
    try testing.expect(try queue.onHold());
    try testing.expectEqual(@as(i32, 4), queue.dequeue().?);

    // Release and dequeue last
    try testing.expect(queue.releaseHold());
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);

    try testing.expect(queue.isEmpty());
}

test "Queue: multiple items on hold simultaneously" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);
    try queue.enqueue(40);
    try queue.enqueue(50);

    // Put first and second items on hold
    try testing.expect(try queue.onHoldAt(0));
    try testing.expect(try queue.onHoldAt(1));
    try testing.expectEqual(@as(usize, 2), queue.holdCount());

    // Dequeue should skip first two and return third
    try testing.expectEqual(@as(i32, 30), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 4), queue.size());

    // Hold count should still be 2
    try testing.expectEqual(@as(usize, 2), queue.holdCount());

    // Dequeue should return fourth item
    try testing.expectEqual(@as(i32, 40), queue.dequeue().?);

    // Release first hold
    try testing.expect(queue.releaseHoldAt(0));
    try testing.expectEqual(@as(usize, 1), queue.holdCount());

    // Dequeue should now return first item
    try testing.expectEqual(@as(i32, 10), queue.dequeue().?);

    // Dequeue should return last item (second is still on hold)
    try testing.expectEqual(@as(i32, 50), queue.dequeue().?);

    // Release second hold
    try testing.expect(queue.releaseHoldAt(0));
    try testing.expectEqual(@as(usize, 0), queue.holdCount());

    // Dequeue last item
    try testing.expectEqual(@as(i32, 20), queue.dequeue().?);
    try testing.expect(queue.isEmpty());
}

test "Queue: hold at specific positions" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    try queue.enqueue(4);

    // Hold position 1 (second item)
    try testing.expect(try queue.onHoldAt(1));
    try testing.expect(queue.isPositionOnHold(1));
    try testing.expect(!queue.isPositionOnHold(0));

    // Dequeue should return first item
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);

    // Now second item is at position 0 and still on hold
    try testing.expect(queue.isPositionOnHold(0));

    // Dequeue should skip it and return third
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
}

test "Queue: all items on hold" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    // Put all items on hold
    try testing.expect(try queue.onHoldAt(0));
    try testing.expect(try queue.onHoldAt(1));
    try testing.expect(try queue.onHoldAt(2));
    try testing.expectEqual(@as(usize, 3), queue.holdCount());

    // Dequeue should return null
    try testing.expectEqual(@as(?i32, null), queue.dequeue());
    try testing.expectEqual(@as(usize, 3), queue.size());

    // Release all holds
    queue.releaseAllHolds();
    try testing.expectEqual(@as(usize, 0), queue.holdCount());

    // Now should dequeue normally
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
}

test "Queue: cannot hold same position twice" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(10);
    try queue.enqueue(20);

    // First hold succeeds
    try testing.expect(try queue.onHoldAt(0));

    // Second hold on same position fails
    try testing.expect(!(try queue.onHoldAt(0)));
    try testing.expectEqual(@as(usize, 1), queue.holdCount());
}

test "Queue: hold invalid position" {
    var queue = Queue(i32).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(10);

    // Cannot hold position beyond queue size
    try testing.expect(!(try queue.onHoldAt(5)));
    try testing.expectEqual(@as(usize, 0), queue.holdCount());
}
