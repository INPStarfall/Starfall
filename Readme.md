Starfall Scripting Environment
----------

*Note: Links are subject to change.*
- Development Thread: [`http://www.wiremod.com/forum/developers-showcase/22739-starfall-processor.html`](http://www.wiremod.com/forum/developers-showcase/22739-starfall-processor.html?goto=newpost).
- Documentation: [`http://sf.inp.io`](http://sf.inp.io).

Contributor information
----------


If you want to contribute to Starfall, you are required to abide to this set of rules, to make developing Starfall a pleasant experience for everyone and to keep up the quality.

**Commit message guidelines**
- There should only ever be one logical change per commit. Separate them into clear cut changes, regardless of size.
- Commit messages must be descriptive and concise.
  - E.g Good: `Added function: newFunction()`; Bad: `fixing the fix of the fix`.
- New features are never pushed directly into the repo, make a pull request with your feature branch an another developer will review it.
- Personal style can be implemented, as long as it adheres to the previous guidelines.
  - E.g [`"[Added] Burst/PersonalQuota/DefaultQuota for SF Holograms"`](https://github.com/INPStarfall/Starfall/commit/7dfb693a5937d18d4e9f6c0135773bc6326b9c60), [`"Fix entities not getting wrapped by SF.WrapObject"`](https://github.com/INPStarfall/Starfall/commit/644dac74aef7800ecab1e6a2b8d17f26843d3842) & [`"Added ents_methods:getColor()"`](https://github.com/INPStarfall/Starfall/commit/9ceee328bd884819b3015dedda3b197b12134ef3).
- This is an example of what ***NOT*** to do: [`"fixes and changes"`](https://github.com/INPStarfall/Starfall/commit/d6b36328ce19da9a9b7f04e4c09266c8fd60a466).

**Codestyle guidelines**
- No GLua-specific syntax. 
  - E.g. don't use `//`, `/**/`, `&&`, `||`, etc.
- Use tabs for indentation, don't use spaces or other whitespace characters.
- Use [LuaDoc-style](http://keplerproject.github.io/luadoc/manual.html) comments on external user API functions and libraries. Use reasonable documentation for internal API functions and libraries.
- Add comments when code functionality is not clear or when the purpose of the code is not obvious.
  - See: [http://codinghorror.com/blog/2008/07/coding-without-comments.html](http://codinghorror.com/blog/2008/07/coding-without-comments.html).
- Function and variable names are supposed to be in `camelCase`, constructor functions, however, are supposed to be in `CamelCase`.
- No parentheses around conditionals used for program logic.
  - E.g. if conditions/loop headers, unless absolutely necessary.
- Use spaces between parentheses and their enclosing body. 
  - E.g. `print( "Hello" )` & `function f ( args )` & `f( args )`.
- Use spaces before the argument list of a function definition. 
  - E.g. `fuction func (var1, var2)`.
- Use spaces after semicolons, as well as commas. 
  - E.g. `f( a1, a2, a3 ); f2( a1, a2, a3 )`.
- Use spaces before any unary operator; before and after any binary operator. 
  - E.g. `local var = 5 + 3` and `local var2 = -var + 3`.
- Use of one-liners/ single-line multi-statements is discouraged. 
  - E.g. `var = 5; var2 = 10; var3 = 15`.
- Do not use semicolons at the end of statements, unless required to separate single-line multi-statements.
- Short circuiting, `a = b and c or d`, is only permitted if used as a ternary operator. Do not use it for program logic. 
  - E.g. Good: `print( a and "Hello" or "Hi" )`; Bad: `a and print("Hello") or print("Hi")`;

**Release strategy**
- We are using [Semantic Versioning](http://semver.org) in the format of `Major.Minor.Sub-minor`.
  - E.g. `2.0.5`. 
- Only changes in major version can break compatibility, backwards compatibility is guaranteed within the same major version.
  - E.g. `2.x.x` set will always be cross-compatible. 
- Functions can be deprecated between minor versions and will then be removed in the next major release.
  - E.g function `helloWorld()` may become deprecated between `2.0.0` and `2.1.0` and will be removed in `3.0.0`.
- Branch naming will follow `Major.Minor`.
- Every minor release will belong in a branch specifically for that release. The HEAD commit will be tagged upon release. 
- When Hotfixes and patches are required, they will be added to the branch for that release and tagged.
- Once a branch is released, features **cannot** be added to it.
