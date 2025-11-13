const std = @import("std");
const Allocator = std.mem.Allocator;

/// A generic FIFO (First-In-First-Out) queue implementation
/// Uses a dynamic array-based circular buffer for efficient operations
pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        head: usize,
        tail: usize,
        count: usize,
        allocator: Allocator,
        hold_indices: std.ArrayList(usize),

        /// Initialize a new queue with the given allocator
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = &[_]T{},
                .head = 0,
                .tail = 0,
                .count = 0,
                .allocator = allocator,
                .hold_indices = std.ArrayList(usize){},
            };
        }

        /// Free all memory used by the queue
        pub fn deinit(self: *Self) void {
            if (self.items.len > 0) {
                self.allocator.free(self.items);
            }
            self.hold_indices.deinit(self.allocator);
            self.* = undefined;
        }

        /// Add an item to the back of the queue
        pub fn enqueue(self: *Self, item: T) !void {
            if (self.count == self.items.len) {
                try self.grow();
            }

            self.items[self.tail] = item;
            self.tail = (self.tail + 1) % self.items.len;
            self.count += 1;
        }

        /// Remove and return the first item that is not on hold
        /// Returns null if the queue is empty or all items are on hold
        pub fn dequeue(self: *Self) ?T {
            if (self.count == 0) {
                return null;
            }

            // Find first item not on hold
            var position: usize = 0;
            while (position < self.count) : (position += 1) {
                if (!self.isPositionOnHold(position)) {
                    const idx = (self.head + position) % self.items.len;
                    const item = self.items[idx];
                    
                    // Remove the item by shifting
                    self.removeAtPosition(position);
                    return item;
                }
            }

            // All items are on hold
            return null;
        }

        /// Peek at the front item without removing it
        /// Returns null if the queue is empty
        pub fn peek(self: *Self) ?T {
            if (self.count == 0) {
                return null;
            }
            return self.items[self.head];
        }

        /// Check if the queue is empty
        pub fn isEmpty(self: *Self) bool {
            return self.count == 0;
        }

        /// Get the number of items in the queue
        pub fn size(self: *Self) usize {
            return self.count;
        }

        /// Clear all items from the queue
        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
            self.count = 0;
            self.hold_indices.clearRetainingCapacity();
        }

        /// Put an item at the specified position on hold
        /// Position 0 is the front, 1 is second, etc.
        /// Returns true if successful, false if position is invalid or already on hold
        pub fn onHoldAt(self: *Self, position: usize) !bool {
            if (position >= self.count) {
                return false;
            }
            
            // Check if already on hold
            for (self.hold_indices.items) |held_pos| {
                if (held_pos == position) {
                    return false;
                }
            }
            
            try self.hold_indices.append(self.allocator, position);
            return true;
        }

        /// Put the front item (position 0) on hold
        /// Returns true if successful, false if queue is empty or already on hold
        pub fn onHold(self: *Self) !bool {
            return self.onHoldAt(0);
        }

        /// Release the hold on an item at the specified position
        /// Returns true if successful, false if position was not on hold
        pub fn releaseHoldAt(self: *Self, position: usize) bool {
            for (self.hold_indices.items, 0..) |held_pos, i| {
                if (held_pos == position) {
                    _ = self.hold_indices.orderedRemove(i);
                    return true;
                }
            }
            return false;
        }

        /// Release the hold on the front item (position 0)
        pub fn releaseHold(self: *Self) bool {
            return self.releaseHoldAt(0);
        }

        /// Release all holds
        pub fn releaseAllHolds(self: *Self) void {
            self.hold_indices.clearRetainingCapacity();
        }

        /// Check if an item at the specified position is on hold
        pub fn isPositionOnHold(self: *Self, position: usize) bool {
            for (self.hold_indices.items) |held_pos| {
                if (held_pos == position) {
                    return true;
                }
            }
            return false;
        }

        /// Check if the front item is on hold
        pub fn isOnHold(self: *Self) bool {
            return self.isPositionOnHold(0);
        }

        /// Get the number of items currently on hold
        pub fn holdCount(self: *Self) usize {
            return self.hold_indices.items.len;
        }

        /// Remove item at position and shift remaining items
        fn removeAtPosition(self: *Self, position: usize) void {
            // Shift items after the removed position
            var i: usize = position;
            while (i < self.count - 1) : (i += 1) {
                const current_idx = (self.head + i) % self.items.len;
                const next_idx = (self.head + i + 1) % self.items.len;
                self.items[current_idx] = self.items[next_idx];
            }
            
            self.tail = if (self.tail == 0) self.items.len - 1 else self.tail - 1;
            self.count -= 1;
            
            // Update hold indices: remove the position and decrement positions after it
            var i_hold: usize = 0;
            while (i_hold < self.hold_indices.items.len) {
                if (self.hold_indices.items[i_hold] == position) {
                    _ = self.hold_indices.orderedRemove(i_hold);
                } else {
                    if (self.hold_indices.items[i_hold] > position) {
                        self.hold_indices.items[i_hold] -= 1;
                    }
                    i_hold += 1;
                }
            }
        }

        /// Grow the internal buffer when capacity is reached
        fn grow(self: *Self) !void {
            const new_capacity = if (self.items.len == 0) 8 else self.items.len * 2;
            const new_items = try self.allocator.alloc(T, new_capacity);

            // Copy items in order from head to tail
            if (self.count > 0) {
                var i: usize = 0;
                var idx = self.head;
                while (i < self.count) : (i += 1) {
                    new_items[i] = self.items[idx];
                    idx = (idx + 1) % self.items.len;
                }
            }

            if (self.items.len > 0) {
                self.allocator.free(self.items);
            }

            self.items = new_items;
            self.head = 0;
            self.tail = self.count;
        }
    };
}
