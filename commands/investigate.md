Investigate and troubleshoot a bug using an evidence file with request details, variables, user context, and errors.

Arguments: $ARGUMENTS (path to the evidence markdown file)

Instructions:

1. Read the evidence file specified in $ARGUMENTS and extract:
   - Request details (endpoint, method, GraphQL query/mutation)
   - Variables or payload
   - User context (user ID, role, tenant, etc.)
   - Error messages and stack traces
   - Any additional context provided

2. Identify the entry point for the request:
   - For GraphQL: Search for the resolver/mutation/query definition matching the operation name
   - For REST: Search for the controller/route handler matching the endpoint
   - Use file paths from stack traces as primary hints for locating relevant code

3. Trace the complete request flow by reading all files involved:
   - Route definitions or GraphQL schema
   - Controllers or Resolvers
   - Services and business logic
   - Middleware (authentication, validation, logging, error handling)
   - Database queries and repository layer
   - DTOs, types, and interfaces
   - Build a complete understanding of the data flow from request to response

4. Ask the user if they want to provide a read-only database connection for additional context:
   - If yes, ask which database type: PostgreSQL, MySQL, or MongoDB
   - Then ask for the connection string
   - Use the appropriate CLI tool for read-only queries:
     - PostgreSQL: `psql "<connection-string>" -c "<query>"`
     - MySQL: `mysql -h <host> -u <user> -p<password> <database> -e "<query>"`
     - MongoDB: `mongosh "<connection-string>" --eval "<query>"`
   - Query relevant data based on evidence (user data, entity states, permissions)
   - IMPORTANT: Only execute SELECT or find operations - never modify data

5. Analyze the bug by cross-referencing:
   - The error message and stack trace with the traced code flow
   - The user context and variables with expected data states
   - Database query results (if available) with the logic's assumptions
   - Identify the exact root cause and the conditions that trigger it

6. Present the investigation report in this format:

   ---
   # Investigation Report

   ## Error Explanation
   [Clear explanation of what the error means and why it occurs in this context]

   ## Analysis Process
   [Step-by-step breakdown of how the error was traced through the codebase]
   1. Entry point: `path/to/file.ts:line`
   2. Flow: `controller.ts` → `service.ts` → `repository.ts`
   3. Root cause identified at: `path/to/file.ts:line`

   ## Root Cause
   [Detailed explanation of the root cause with specific code references]

   ## The Fix
   [Specific code changes needed to resolve the issue]

   **File**: `path/to/file.ts`
   ```typescript
   // Before
   const value = object.property;

   // After
   const value = object?.property;
   if (!value) {
     throw new BadRequestException('Property is required');
   }
   ```

   ## Impact Assessment
   **Risk Level**: LOW / MEDIUM / HIGH

   - **Scope**: [What parts of the system are affected by this fix]
   - **Breaking changes**: [Any API or behavior changes to be aware of]
   - **Dependencies**: [Other code that relies on the modified code]
   - **Test coverage**: [Existing tests that may need updates]

   ## Before vs After Comparison

   | Aspect | Before | After |
   |--------|--------|-------|
   | Behavior | [Old behavior description] | [New behavior description] |
   | Edge cases | [How edge cases were handled] | [How edge cases will be handled] |
   | Error handling | [Previous error handling] | [New error handling approach] |

   ## Recommendations
   - [ ] Apply the fix
   - [ ] Add/update tests for this scenario
   - [ ] Consider related edge cases that may have similar issues
   ---

7. After presenting the report, ask the user if they want to apply the suggested fix.
   - If yes, make the code changes as specified in the report
   - Run any relevant tests if available
   - Report what was changed
