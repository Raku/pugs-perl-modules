
use Test::More tests => 3;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use_ok( 'Pugs::Compiler::RegexPerl5' );
use Pugs::Compiler::Rule;
no warnings qw( once );

use Pugs::Emitter::Rule::Perl5::Regex;
sub compile {
    my ( $class, $rule_source, $param ) = @_;
    my $self = { source => $rule_source };
    warn "Error in rule: unknown parameter '$_'" 
        for keys %$param;
    #print 'rule source: ', $self->{source}, "\n";
    #print "match: ", Dumper( Pugs::Grammar::Rule->rule( $self->{source} ) );
    my $ast = Pugs::Grammar::Rule->rule( 
            $self->{source} )->();
    #print "ast: ",Dumper($ast),"\n";
    #die "Error in rule: '$rule_source' at: '$ast->tail'\n" if $ast->tail;
    #print 'rule ast: ', do{use Data::Dumper; Dumper($ast{capture})};

    $self->{perl5} = Pugs::Emitter::Rule::Perl5::Regex::emit( 
                $self->{grammar}, $ast, $self );
        
    #print 'rule perl5: ', do{use Data::Dumper; Dumper($self->{perl5})};
    return Pugs::Compiler::RegexPerl5->compile( $self->{perl5} );
}

{
    my $rule = __PACKAGE__->compile( 'abc' );
    my $match = $rule->match( "xabcde" );
    #print "Source: ", do{use Data::Dumper; Dumper($rule->{perl5})};
    #print "Match: ", do{use Data::Dumper; Dumper($match)};
    is( $match?1:0, 1, 'booleanify' );
    is( "$match", "abc", 'stringify 1' );
}

