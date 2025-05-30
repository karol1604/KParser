const std = @import("std");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span_ = @import("span.zig");
const diagnostics = @import("diagnostics.zig");

const Report = diagnostics.Report;

const Span = span_.Span;

const TypeId = usize;

const EMPTY_TYPE_ID: TypeId = 0;
const INT_TYPE_ID: TypeId = 1;
const BOOL_TYPE_ID: TypeId = 2;

pub const CheckedExpression = struct {
    typeId: TypeId,
    data: CheckedExpressionData,
};

const CheckedFunctionParameter = struct {
    name: []const u8,
    typeId: TypeId,
};

const CheckedExpressionData = union(enum) {
    IntLiteral: i64,
    BoolLiteral: bool,
    Identifier: []const u8,

    Unary: struct {
        operator: ast.UnaryOperator,
        right: *const CheckedExpression,
    },

    Binary: struct {
        left: *const CheckedExpression,
        operator: ast.BinaryOperator,
        right: *const CheckedExpression,
    },

    VariableDeclaration: struct {
        name: []const u8,
        value: *const CheckedExpression,
    },

    FunctionDeclaration: struct {
        parameters: std.ArrayList(*CheckedFunctionParameter),
        returnType: TypeId,
        body: std.ArrayList(*CheckedExpression),
    },

    Block: std.ArrayList(*CheckedExpression),
};

const Type = union(enum) {
    Named: []const u8,
    Function: struct {
        parameters: []TypeId,
        returnType: TypeId,
    },
};

const Scope = struct {
    variables: std.StringHashMap(TypeId),
    types: std.StringHashMap(TypeId),
    types_array: std.ArrayList(Type),

    pub fn init(alloc: std.mem.Allocator) !Scope {
        return Scope{
            .variables = std.StringHashMap(TypeId).init(alloc),
            .types = std.StringHashMap(TypeId).init(alloc),
            .types_array = std.ArrayList(Type).init(alloc),
        };
    }

    pub fn deinit(self: *Scope) void {
        self.variables.deinit();
        self.types.deinit();
        self.types_array.deinit();
    }
};

pub const Checker = struct {
    alloc: std.mem.Allocator,
    expressions: []*ast.Expression,
    scopes: std.ArrayList(Scope),
    source: []const u8,

    pub fn init(alloc: std.mem.Allocator, exprs: []*ast.Expression, source: []const u8) !Checker {
        var scopes = std.ArrayList(Scope).init(alloc);
        errdefer {
            for (scopes.items) |*scope| scope.deinit();
            scopes.deinit();
        }

        try scopes.append(try Scope.init(alloc));

        var c = Checker{
            .alloc = alloc,
            .expressions = exprs,
            .scopes = scopes,
            .source = source,
        };

        _ = try c.declareType(.{ .Named = "∅" });
        _ = try c.declareType(.{ .Named = "ℤ" });
        _ = try c.declareType(.{ .Named = "Bool" });

        return c;
    }

    fn makePointer(self: *const Checker, comptime T: type, val: T) !*T {
        const ptr = try self.alloc.create(T);
        ptr.* = val;
        return ptr;
    }

    fn typeNameFromId(self: *const Checker, id: TypeId) ?[]const u8 {
        for (self.scopes.items) |*scope| {
            var it = scope.types.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == id) {
                    return entry.key_ptr.*;
                }
            }
        }

        return null;
    }

    fn currentScope(self: *const Checker) *Scope {
        return &self.scopes.items[self.scopes.items.len - 1];
    }

    fn pushScope(self: *Checker) !void {
        const newScope = try Scope.init(self.alloc);
        try self.scopes.append(newScope);
    }

    fn popScope(self: *Checker) void {
        const last = self.scopes.items.len - 1;
        self.scopes.items[last].deinit();
        _ = self.scopes.pop();
    }

    fn declareType(self: *Checker, ty: Type) !TypeId {
        const scope = self.currentScope();
        const id = scope.types_array.items.len;
        // std.debug.print("Declaring type `{s}` with id {d}\n", .{ ty.Named, id });
        // if (scope.types.get(name) != null) {
        //     std.debug.print("Type `{s}` already declared\n", .{name});
        //     return error.TypeAlreadyDeclared;
        // }

        if (std.meta.activeTag(ty) == .Named) try scope.types.put(ty.Named, id);
        try scope.types_array.append(ty);

        return id;
    }

    fn indexOfType(scope: *const Scope, name: []const u8) ?usize {
        for (scope.*.types_array.items, 0..) |typ, i| {
            switch (typ) {
                .Named => |n| {
                    if (std.mem.eql(u8, n, name)) {
                        std.debug.print("Looking for `{s}` in scope, found {d}\n", .{ name, i });
                        return i;
                    }
                },
                .Function => |_| {
                    // TODO: handle function types
                },
            }
        }
        return null;
    }

    // TODO: this should take in a `Type` instead of a string
    fn lookupType(self: *const Checker, name_: ?[]const u8) ?TypeId {
        if (name_) |name| {
            for (0..self.scopes.items.len) |i| {
                const scope = self.scopes.items[self.scopes.items.len - i - 1];
                _ = indexOfType(&scope, name);
                if (scope.types.get(name) != null) {
                    std.debug.print("INFO:: Found type `{s}` in scope {d} with {d} scopes\n", .{ name, self.scopes.items.len - i - 1, self.scopes.items.len });
                    return scope.types.get(name);
                }

                // BUG: should be `!= null` instead of `orelse`
                // return scope.types.get(name) orelse null;
            }
        }
        return null;
    }

    fn declareVar(self: *Checker, name: []const u8, type_id: TypeId) !void {
        const scope = self.currentScope();
        if (scope.variables.get(name) != null) {
            std.debug.print("Variable `{s}` already declared\n", .{name});
            return error.VariableAlreadyDeclared;
        }
        try scope.variables.put(name, type_id);
    }

    fn lookupVar(self: *const Checker, name: []const u8) ?TypeId {
        for (0..self.scopes.items.len) |i| {
            const scope = self.scopes.items[self.scopes.items.len - i - 1];
            return scope.variables.get(name) orelse continue;
        }
        return null;
    }

    pub fn check(self: *Checker) ![]*CheckedExpression {
        var checkedExpressions = std.ArrayList(*CheckedExpression).init(self.alloc);
        errdefer checkedExpressions.deinit();

        for (self.expressions) |expr| {
            const checkedExpr = try self.checkExpression(expr, null);
            try checkedExpressions.append(checkedExpr);
            // Do something with checkedStmt
        }

        return checkedExpressions.items;
    }

    fn checkExpression(self: *Checker, expr: *const ast.Expression, typeHint: ?TypeId) anyerror!*CheckedExpression {
        switch (expr.*.kind) {
            .IntLiteral => |int| return try self.typedExpression(.{ .IntLiteral = int }, expr.*.span, INT_TYPE_ID, typeHint),
            .BoolLiteral => |b| return try self.typedExpression(.{ .BoolLiteral = b }, expr.*.span, BOOL_TYPE_ID, typeHint),
            .Identifier => return try self.checkIdentifier(expr, typeHint),
            .FunctionDeclaration => return try self.checkFunctionDeclaration(expr, typeHint),
            .Unary => return try self.checkUnaryExpression(expr, typeHint),
            .Binary => return try self.checkBinaryExpression(expr, typeHint),
            .Block => return try self.checkBlockExpression(expr, typeHint),
            .VariableDeclaration => return try self.checkVariableDeclaration(expr),
            // else => {
            //     std.debug.print("Unknown expression type \n", .{});
            //     return error.UnknownExpressionType;
            // },
        }
    }

    fn checkIdentifier(
        self: *const Checker,
        expr: *const ast.Expression,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        const ident = expr.*.kind.Identifier;
        const typeId = self.lookupVar(ident);
        if (typeId) |ty| {
            return try self.typedExpression(.{ .Identifier = ident }, expr.*.span, ty, typeHint);
        } else {
            std.debug.print("Unknown variable `{s}` at {any}\n", .{ ident, expr.*.span });
            return error.UnknownVariable;
        }
    }

    fn checkVariableDeclaration(self: *Checker, expr: *const ast.Expression) !*CheckedExpression {
        const varDecl = expr.*.kind.VariableDeclaration;
        const expectedType = self.lookupType(varDecl.type);

        // really?
        if (expectedType == null) {
            if (varDecl.type) |typeName| {
                std.debug.print("Unknown type `{s}` at {any}\n", .{ typeName, expr.*.span });
                return error.UnknownType;
            }
        }

        const value = try self.checkExpression(varDecl.value, expectedType);
        if (self.lookupType(varDecl.name)) |ty| {
            // TODO: remove this unwrap
            std.debug.print("Variable has the same name as type `{s}` at {s}", .{ self.typeNameFromId(ty).?, expr.*.span });
            return error.VariableAlreadyDeclared;
        }
        try self.declareVar(varDecl.name, value.typeId);
        return try self.typedExpression(.{
            .VariableDeclaration = .{
                .name = varDecl.name,
                .value = value,
            },
        }, expr.*.span, EMPTY_TYPE_ID, null);
    }

    fn checkBlockExpression(
        self: *Checker,
        expr: *const ast.Expression,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        const block = expr.*.kind.Block;
        try self.pushScope();
        var body = std.ArrayList(*CheckedExpression).init(self.alloc);
        errdefer body.deinit();

        for (block.body.items) |stmt| {
            const checkedExpr = try self.checkExpression(stmt, null);
            try body.append(checkedExpr);
        }

        if (body.items.len == 0) {
            std.debug.print("Block is empty at {any}\n", .{expr.*.span});
            return error.BlockEmpty;
        }

        self.popScope();

        return try self.typedExpression(
            .{ .Block = body },
            expr.*.span,
            EMPTY_TYPE_ID,
            typeHint,
        );
    }

    fn checkUnaryExpression(
        self: *Checker,
        expr: *const ast.Expression,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        const unary = expr.*.kind.Unary;
        switch (unary.operator) {
            .Not => {
                const right = try self.checkExpression(unary.right, BOOL_TYPE_ID);
                return try self.typedExpression(
                    .{ .Unary = .{
                        .operator = unary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    BOOL_TYPE_ID,
                    typeHint,
                );
            },
            .Plus, .Minus => {
                const right = try self.checkExpression(unary.right, INT_TYPE_ID);
                return try self.typedExpression(
                    .{ .Unary = .{
                        .operator = unary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    INT_TYPE_ID,
                    typeHint,
                );
            },
        }
    }

    fn checkBinaryExpression(
        self: *Checker,
        expr: *const ast.Expression,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        const binary = expr.*.kind.Binary;
        switch (binary.operator) {
            .Plus, .Minus, .Multiply, .Divide, .Exponent => {
                const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                return try self.typedExpression(
                    .{ .Binary = .{
                        .left = left,
                        .operator = binary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    INT_TYPE_ID,
                    typeHint,
                );
            },
            .LessThan, .GreaterThan, .LessThanOrEqual, .GreaterThanOrEqual => {
                const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                return try self.typedExpression(
                    .{ .Binary = .{
                        .left = left,
                        .operator = binary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    BOOL_TYPE_ID,
                    typeHint,
                );
            },
            .Equal, .NotEqual => {
                const left = try self.checkExpression(binary.left, null);
                const right = try self.checkExpression(binary.right, left.typeId);

                return try self.typedExpression(
                    .{ .Binary = .{
                        .left = left,
                        .operator = binary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    BOOL_TYPE_ID,
                    typeHint,
                );
            },
            .LogicalAnd, .LogicalOr => {
                const left = try self.checkExpression(binary.left, BOOL_TYPE_ID);
                const right = try self.checkExpression(binary.right, BOOL_TYPE_ID);

                return try self.typedExpression(
                    .{ .Binary = .{
                        .left = left,
                        .operator = binary.operator,
                        .right = right,
                    } },
                    expr.*.span,
                    BOOL_TYPE_ID,
                    typeHint,
                );
            },
            // else => {
            //     return error.UnknownBinaryOperator;
            // },
        }
    }

    fn checkFunctionDeclaration(
        self: *Checker,
        expr: *const ast.Expression,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        const decl = expr.*.kind.FunctionDeclaration;
        const returnType = if (decl.returnType) |ty| self.lookupType(ty.*.kind.Identifier) else null;
        var params = std.ArrayList(*CheckedFunctionParameter).init(self.alloc);
        var body = std.ArrayList(*CheckedExpression).init(self.alloc);

        try self.pushScope();

        for (decl.parameters.items) |param| {
            const paramType = self.lookupType(param.type);
            if (paramType == null) {
                std.debug.print("Unknown type `{s}` at {any}\n", .{ param.type, expr.*.span });
                return error.UnknownType;
            }
            try params.append(try self.makePointer(CheckedFunctionParameter, .{
                .name = param.name,
                .typeId = paramType.?,
            }));
            try self.declareVar(param.name, paramType.?);
        }

        for (decl.body.items) |stmt| {
            const checkedExpr = try self.checkExpression(stmt, null);
            try body.append(checkedExpr);
        }

        if (body.items.len == 0) {
            std.debug.print("Function body is empty at {any}\n", .{expr.*.span});
            return error.FunctionBodyEmpty;
        }
        const lastExprTypeId = body.items[body.items.len - 1].*.typeId;
        if (returnType != null and returnType != lastExprTypeId) {
            // std.debug.print("Type mismatch: Function return type marked as `{s}` but returns `{s}` at {any}\n", .{ self.typeNameFromId(returnType.?).?, self.typeNameFromId(lastStmtTypeId).?, expr.*.kind.FunctionDeclaration.body.items[body.items.len - 1].*.span });
            std.debug.print("Type mismatch: Function return type marked as `{s}` but returns `{s}` at {any}\n", .{ self.typeNameFromId(returnType.?).?, self.typeNameFromId(lastExprTypeId).?, decl.returnType.?.span });

            return error.FunctionReturnTypeMismatch;
        }

        var paramTypeIds = std.ArrayList(TypeId).init(self.alloc);

        // BUG: this is bad bc if the type is a random value, it will still take the last statement's type
        const returnTypeId: TypeId = returnType orelse lastExprTypeId;

        // defer paramTypeIds.deinit();

        for (params.items) |param| {
            std.debug.print("Parameter `{s}` s\n", .{param.name});
            try paramTypeIds.append(param.*.typeId);
        }

        self.popScope();

        // TODO: check if type already exists
        const t_id = try self.declareType(.{ .Function = .{
            .parameters = paramTypeIds.items,
            .returnType = returnTypeId,
        } });

        // NOTE: Hack here
        return self.typedExpression(
            .{ .FunctionDeclaration = .{
                .parameters = params,
                .returnType = returnType orelse lastExprTypeId,
                .body = body,
            } },
            expr.*.span,
            t_id,
            typeHint,
        );
    }

    fn typedExpression(
        self: *const Checker,
        res: CheckedExpressionData,
        span: Span,
        resType: TypeId,
        typeHint: ?TypeId,
    ) !*CheckedExpression {
        if (typeHint != null and resType != typeHint) {
            // std.debug.print("Type mismatch: expected type {s}, got {s} at {s}\n", .{ self.typeNameFromId(typeHint.?).?, self.typeNameFromId(resType).?, span });
            std.debug.print("Type mismatch: expected type {d}, got {d} at {s}\n", .{ typeHint.?, resType, span });

            return error.TypeMismatch;
        } else {
            return self.makePointer(CheckedExpression, CheckedExpression{
                .typeId = resType,
                .data = res,
            });
        }
    }
};
