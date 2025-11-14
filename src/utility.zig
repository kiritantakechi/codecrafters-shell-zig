const builtin = @import("builtin");
const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Utility = struct {
    pub fn isSpace(ch: u8) bool {
        return switch (ch) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }

    pub fn isExecutable(full_path: []const u8) bool {
        std.fs.accessAbsolute(full_path, .{}) catch return false;

        if (builtin.os.tag == .windows) return true;

        const file = std.fs.openFileAbsolute(full_path, .{}) catch return false;
        defer file.close();
        const stat = file.stat() catch return false;
        return (stat.mode & 0o111) != 0;
    }

    pub fn findExe(allocator: Allocator, exe_name: []const u8) ![]u8 {
        const path_env = std.process.getEnvVarOwned(allocator, "PATH") catch return error.PathNotFound;
        defer allocator.free(path_env);

        const path_sep = if (builtin.os.tag == .windows) ';' else ':';
        var dir_it = std.mem.splitScalar(u8, path_env, path_sep);

        while (dir_it.next()) |dir| {
            if (dir.len == 0) continue;

            const candidates = if (builtin.os.tag == .windows and !std.mem.endsWith(u8, exe_name, ".exe"))
                &[_][]const u8{ exe_name, try std.fmt.allocPrint(allocator, "{s}.exe", .{exe_name}) }
            else
                &[_][]const u8{exe_name};
            defer if (builtin.os.tag == .windows and candidates.len > 1) allocator.free(candidates[1]);

            for (candidates) |candidate| {
                const full_path = try std.fs.path.join(allocator, &.{ dir, candidate });
                if (isExecutable(full_path)) {
                    return full_path;
                }
                allocator.free(full_path);
            }
        }

        return error.ExecutableNotFound;
    }
};
