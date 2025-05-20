pub const Resource = struct {
    id: usize,
    type: enum { CPU, Memory, IO },
    usage: usize,
};

pub var resource_pool: [16]Resource = undefined;

pub fn registerResource(id: usize, usage: usize, kind: Resource.type) void {
    resource_pool[id] = Resource{ .id = id, .usage = usage, .type = kind };
}
