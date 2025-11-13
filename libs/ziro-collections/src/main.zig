const std = @import("std");

pub const Queue = @import("queue.zig").Queue;

test {
    std.testing.refAllDecls(@This());
}
