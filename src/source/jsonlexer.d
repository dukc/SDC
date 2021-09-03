module source.jsonlexer;

import source.context;
import source.location;

enum TokenType {
	Invalid = 0,
	
	Begin,
	End,
	
	// Comments
	Comment,
	
	// Literals
	StringLiteral,
	CharacterLiteral = StringLiteral,
	IntegerLiteral,
	FloatLiteral,
	
	// Identifier
	Identifier,
	
	// Keywords
	Null, True, False,
	
	// Operators.
	OpenParen,    // (
	CloseParen,   // )
	OpenBracket,  // [
	CloseBracket, // ]
	OpenBrace,    // {
	CloseBrace,   // }
}

struct Token {
	import source.location;
	Location location;
	
	TokenType type;
	
	import source.name;
	Name name;
	
	import source.context;
	string toString(Context context) {
		return (type >= TokenType.Identifier)
			? name.toString(context)
			: location.getFullLocation(context).getSlice();
	}
}

auto lex(Position base, Context context) {
	auto lexer = JsonLexer();
	
	lexer.content = base.getFullPosition(context).getSource().getContent();
	lexer.t.type = TokenType.Begin;
	
	lexer.context = context;
	lexer.base = base;
	lexer.previous = base;
	
	lexer.t.location =  Location(base, base.getWithOffset(lexer.index));
	return lexer;
}

struct JsonLexer {
	enum BaseMap = () {
		auto ret = [
			// WhiteSpaces
			" "    : "-skip",
			"\t"   : "-skip",
			"\v"   : "-skip",
			"\f"   : "-skip",
			"\n"   : "-skip",
			"\r"   : "-skip",
			
			// Comments
			"//" : "!tokenizeComments?lexComment:popComment",
			"/*" : "!tokenizeComments?lexComment:popComment",
			"/+" : "!tokenizeComments?lexComment:popComment",
			
			// Integer literals.
			"0b" : "lexNumeric",
			"0B" : "lexNumeric",
			"0x" : "lexNumeric",
			"0X" : "lexNumeric",
			
			// String literals.
			`"` : "lexString",
			"'" : "lexString",
		];
		
		foreach (i; 0 .. 10) {
			import std.conv;
			ret[to!string(i)] = "lexNumeric";
		}
		
		return ret;
	}();
	
	enum KeywordMap = [
		"null"  : TokenType.Null,
		"true"  : TokenType.True,
		"false" : TokenType.False,
	];
	
	enum OperatorMap = [
		"("  : TokenType.OpenParen,
		")"  : TokenType.CloseParen,
		"["  : TokenType.OpenBracket,
		"]"  : TokenType.CloseBracket,
		"{"  : TokenType.OpenBrace,
		"}"  : TokenType.CloseBrace,
		"\0" : TokenType.End,
	];
	
	import source.lexerutil;
	mixin TokenRangeImpl!(Token, BaseMap, KeywordMap, OperatorMap);
}

unittest {
	auto context = new Context();
	
	auto testlexer(string s) {
		import source.name;
		return lex(
			context.registerMixin(Location.init, s ~ '\0'),
			context);
	}
	
	import source.parserutil;
	
	{
		auto lex = testlexer("");
		lex.match(TokenType.Begin);
		assert(lex.front.type == TokenType.End);
	}
	
	{
		auto lex = testlexer("null(aa[{]true})false");
		lex.match(TokenType.Begin);
		lex.match(TokenType.Null);
		lex.match(TokenType.OpenParen);
		
		auto t = lex.front;
		assert(t.type == TokenType.Identifier);
		assert(t.toString(context) == "aa");
		
		lex.popFront();
		lex.match(TokenType.OpenBracket);
		lex.match(TokenType.OpenBrace);
		lex.match(TokenType.CloseBracket);
		lex.match(TokenType.True);
		lex.match(TokenType.CloseBrace);
		lex.match(TokenType.CloseParen);
		lex.match(TokenType.False);
		
		assert(lex.front.type == TokenType.End);
	}
	
	{
		auto lex = testlexer(`"""foobar"'''balibalo'"\""'"'"'"`);
		lex.match(TokenType.Begin);
		
		foreach (expected; [`""`, `"foobar"`, `''`, `'balibalo'`, `"\""`, `'"'`, `"'"`]) {
			auto t = lex.front;
			
			assert(t.type == TokenType.StringLiteral);
			assert(t.toString(context) == expected);
			lex.popFront();
		}
		
		assert(lex.front.type == TokenType.End);
	}
	
	// Check unterminated strings.
	{
		auto lex = testlexer(`"`);
		lex.match(TokenType.Begin);
		
		auto t = lex.front;
		assert(t.type == TokenType.Invalid);
	}
	
	{
		auto lex = testlexer(`"\`);
		lex.match(TokenType.Begin);
		
		auto t = lex.front;
		assert(t.type == TokenType.Invalid);
	}
	
	{
		auto lex = testlexer(`'`);
		lex.match(TokenType.Begin);
		
		auto t = lex.front;
		assert(t.type == TokenType.Invalid);
	}
	
	{
		auto lex = testlexer(`'\`);
		lex.match(TokenType.Begin);
		
		auto t = lex.front;
		assert(t.type == TokenType.Invalid);
	}
}