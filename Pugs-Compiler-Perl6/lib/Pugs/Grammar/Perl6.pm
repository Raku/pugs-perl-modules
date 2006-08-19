﻿package Pugs::Grammar::Perl6;
use strict;
use warnings;
use base qw(Pugs::Grammar::BaseCategory);
use Pugs::Grammar::StatementControl;
use Pugs::Grammar::StatementModifier;
use Pugs::Grammar::Expression;
use Pugs::Grammar::Pod;

use Pugs::Compiler::Rule;
use Pugs::Runtime::Match;
use Pugs::Grammar::P6Rule; # our local version of Grammar::Rule.pm

use Data::Dumper;

*perl6_expression_or_null = Pugs::Compiler::Token->compile( q(
    <Pugs::Grammar::Expression.parse('no_blocks',1)> 
        { return $_[0]{'Pugs::Grammar::Expression.parse'}->() }
    |
        { return {
            null => 1,
        } }
),
    { grammar => __PACKAGE__ }
)->code;

*block = Pugs::Compiler::Token->compile( q(
    \{ <?ws>? 
        #{ print "block\n" }
        <statements>
        #{ print "matched block\n", Dumper( $_[0]{statements}->data ); }
        <?ws>? \}
        { 
            #print "matched block\n", Dumper( $_[0]{statements}->data ); 
            return { 
                bare_block => $_[0]{statements}->(),
            } 
        }
    |
    \{ <?ws>? \}
        { 
            return { 
                bare_block => { statements => [] } 
            } 
        }
    |
    \-\>  
        [
            <?ws>? <signature_no_invocant> <?ws>? 
            \{ <?ws>? <statements> <?ws>? \}
            { return { 
                pointy_block => $_[0]{statements}->(),
                signature    => $_[0]{signature_no_invocant}->(),
            } }
        |
            <?ws>?
            \{ <?ws>? <statements> <?ws>? \}
            { return { 
                pointy_block => $_[0]{statements}->(),
                signature    => undef,
            } }
        ]
),
    { grammar => __PACKAGE__ }
)->code;

*attribute = Pugs::Compiler::Regex->compile( q(
        (<alnum>+) <?ws> ( [<alnum>|_|\\:\\:]+)
        [
            <?ws> <attribute>
            { return [
                    [ { bareword => $_[0][0]->() }, { bareword => $_[0][1]->() } ], 
                    @{$<attribute>->()},
            ] }
        |
            { return [[ { bareword => $_[0][0]->() }, { bareword => $_[0][1]->() } ]] }
        ]
    |
        (\\:<alnum>+)
        [
            <?ws>? <attribute>
            { return [
                    [ { bareword => $_[0][0]->() }, { num => 1 } ], 
                    @{$<attribute>->()},
            ] }
        |
            { return [[ { bareword => $_[0][0]->() }, { num => 1 } ]] }
        ]
    |
        { return [] }
),
    { grammar => __PACKAGE__ }
)->code;


# Str|Num
*signature_term_type = Pugs::Compiler::Regex->compile( q(
        <Pugs::Grammar::Term.bare_ident>
        [
            <?ws>? \| <?ws>? <signature_term_type>
            { return {
                op1 => '|',
                exp1 => $_[0]{'Pugs::Grammar::Term.bare_ident'}->(),
                exp2 => $<signature_term_type>->(),
            } }
        |
            { return $_[0]{'Pugs::Grammar::Term.bare_ident'}->() }
        ]
    |
        { return undef }
),
    { grammar => __PACKAGE__ }
)->code;


*signature_term_ident = Pugs::Compiler::Token->compile( q(
            # XXX t/subroutines/multidimensional_arglists.t
            \\@ ; <?Pugs::Grammar::Term.ident>
            { return { die => "not implemented" } }
     |
        (  ( <'$'>|<'%'>|<'@'>|<'&'> ) <?Pugs::Grammar::Term.ident> )
            { return $_[0][0]->() }
),
    { grammar => __PACKAGE__ }
)->code;


*signature_term = Pugs::Compiler::Token->compile( q(
        <signature_term_type> : <?ws>?
        (<':'>?)
        (<'*'>?)
        <signature_term_ident>
        (<'?'>?)
        (<?ws>? <'='> <Pugs::Grammar::Expression.parse('no_blocks', 1)>)?
        <?ws>? <attribute> 
            { return {
                default    => $_[0][3] ? $_[0][3][0]{'Pugs::Grammar::Expression.parse'}->() : undef,
                type       => $_[0]{signature_term_type}->(),
                name       => $_[0]{signature_term_ident}->(),
                attribute  => $_[0]{attribute}->(),
                
                named_only => $_[0][0]->(),
                is_slurpy  => $_[0][1]->(),
                optional   => $_[0][2]->(),
            } }
    #|
    #    { return undef }
),
    { grammar => __PACKAGE__ }
)->code;


*signature_no_invocant = Pugs::Compiler::Token->compile( q(
        <signature_term>
        [
            <?ws>? <','> <?ws>? <signature_no_invocant>
            { return [
                    $_[0]{signature_term}->(), 
                    @{$_[0]{signature_no_invocant}->()},
            ] }
        |
            { return [ $_[0]{signature_term}->() ] }
        ]
    |
        { return [] }
),
    { grammar => __PACKAGE__ }
)->code;


*signature = Pugs::Compiler::Token->compile( q(
        <signature_term> <?ws>? <':'>
        [
            <?ws>? <signature_no_invocant>
            { return [
                    {
                        %{$_[0]{signature_term}->()}, 
                        invocant => 1,
                    },
                    @{$_[0]{signature_no_invocant}->()},
            ] }
        |
            { return [ 
                    {
                        %{$_[0]{signature_term}->()}, 
                        invocant => 1,
                    },
            ] }
        ]
    |
        <signature_no_invocant> 
            { return $_[0]{signature_no_invocant}->()
            }
),
    { grammar => __PACKAGE__ }
)->code;

*sub_decl_name = Pugs::Compiler::Token->compile( q(
    ( my    | <null> ) <?ws>?
    ( multi | <null> ) <?ws>?
    ( submethod | method | sub ) <?ws>? 
    ( <?Pugs::Grammar::Term.ident>? ) 
        { return { 
            my         => $_[0][0]->(),
            multi      => $_[0][1]->(),
            statement  => $_[0][2]->(),
            name       => $_[0][3]->(),
        } }
    |
    ( multi ) <?ws>?
    ( <?Pugs::Grammar::Term.ident>? ) 
        { return { 
            multi      => $_[0][0]->(),
            statement  => 'sub',
            name       => $_[0][1]->(),
        } }

),
    { grammar => __PACKAGE__ }
)->code;

*sub_signature = Pugs::Compiler::Token->compile( q(
        # (sig)
        <'('> <?ws>? <signature> <?ws>? <')'>
        { 
            #print "sig ", Dumper( $_[0]{signature}->() );
            return $_[0]{signature}->() 
        }
    |
        { return [] }
),
    { grammar => __PACKAGE__ }
)->code;

*sub_decl = Pugs::Compiler::Token->compile( q(
    <sub_decl_name> <?ws>? 
        # (sig)
        <sub_signature> <?ws>? 
        # attr
        <attribute> <?ws>?
        <block>        
        { 
          return { 
            multi      => $_[0]{sub_decl_name}->()->{multi},
            my         => $_[0]{sub_decl_name}->()->{my},
            statement  => $_[0]{sub_decl_name}->()->{statement},
            name       => $_[0]{sub_decl_name}->()->{name},
            
            attribute  => $_[0]{attribute}->(),
            signature  => $_[0]{sub_signature}->(),
            block      => $_[0]{block}->(),
        } }
),
    { grammar => __PACKAGE__ }
)->code;


*rule_decl_name = Pugs::Compiler::Token->compile( q(
    ( multi | <null> ) <?ws>?
    ( rule  | regex | token ) <?ws>?
    ( <?Pugs::Grammar::Term.ident>? ) 
        { return { 
            multi      => $_[0][0]->(),
            statement  => $_[0][1]->(),
            name       => $_[0][2]->(),
        } }
),
    { grammar => __PACKAGE__ }
)->code;


*rule_decl = Pugs::Compiler::Token->compile( q(
    <rule_decl_name> <?ws>?   
        # (sig)
        <sub_signature> <?ws>? 
        # attr
        <attribute> <?ws>?
    <'{'>  
        <?ws>?
    [
        <Pugs::Grammar::P6Rule.rule>     
        <?ws>?
    <'}'>
    { return { 
            multi      => $_[0]{rule_decl_name}->()->{multi},
            statement  => $_[0]{rule_decl_name}->()->{statement},
            name       => $_[0]{rule_decl_name}->()->{name},
            
            attribute  => $_[0]{attribute}->(),
            signature  => $_[0]{sub_signature}->(),

            # pass the match tree to the emitter
            block      => $_[0]{'Pugs::Grammar::P6Rule.rule'}->(),
    } }
    
    |
        # XXX better error messages
        { return { die "invalid rule syntax" } }
    ]
),
    { grammar => __PACKAGE__ }
)->code;


# class


*class_decl_name = Pugs::Compiler::Token->compile( q(
    ( my    | <null> ) <?ws>?
    ( class | grammar | module | role | package ) <?ws>? 
    ( <?Pugs::Grammar::Term.cpan_bareword> | <?Pugs::Grammar::Term.bare_ident> | <null> ) 
        { return { 
            my         => $_[0][0]->(),
            statement  => $_[0][1]->(),
            name       => $_[0][2]->(),
        } }
),
    { grammar => __PACKAGE__ }
)->code;


*class_decl = Pugs::Compiler::Token->compile( q(
    <class_decl_name> <?ws>? 
        <attribute> <?ws>?
        <block>?
        { 
          #print "matched block\n", Dumper( $_[0]{block}[0]->data ); 
          return { 
            my         => $_[0]{class_decl_name}->()->{my},
            statement  => $_[0]{class_decl_name}->()->{statement},
            name       => $_[0]{class_decl_name}->()->{name},
            
            attribute  => $_[0]{attribute}->(),
            block      => defined $_[0]{block}[0]
                          ? $_[0]{block}[0]->()
                          : undef ,
        } }
),
    { grammar => __PACKAGE__ }
)->code;



# /class


*begin_block = Pugs::Compiler::Token->compile( q(
    (          
   BEGIN 
 | CHECK 
 | INIT 
 | END
 | START
 | FIRST
 | ENTER
 | LEAVE
 | KEEP
 | UNDO
 | NEXT
 | LAST
 | PRE
 | POST
 | CATCH
 | CONTROL
    ) <?ws>? <block>        
        { return { 
            trait  => $_[0][0]->(),
            %{ $_[0]{block}->() },
        } }
),
    { grammar => __PACKAGE__ }
)->code;

*statement = Pugs::Compiler::Token->compile( q(
    <Pugs::Grammar::StatementControl.parse>
        { 
            return $/->{'Pugs::Grammar::StatementControl.parse'}->();
        }
    |
    <begin_block>
        { return $_[0]{begin_block}->();
        }
    |
    <Pugs::Grammar::Expression.parse('allow_modifier', 1)> 
        { 
            return $_[0]{'Pugs::Grammar::Expression.parse'}->();
        } 
),
    { grammar => __PACKAGE__ }
)->code;

*statements = Pugs::Compiler::Token->compile( q(
    [ ; <?ws>? ]*

    [
        <before <'}'> > { $::_V6_SUCCEED = 0 } 
    |
        <statement> 
        <?ws>? [ ; <?ws>? ]*
        [
            <before <'}'> > { $::_V6_SUCCEED = 0 }
        |
            <statements> 
            { return {
                statements => [
                        $_[0]{statement}->(),
                        @{ $_[0]{statements}->()->{statements} },
                    ]
                }
            }
        |
            { 
            return {
                statements => [ $_[0]{statement}->() ],
            } }
        ]
    ]
),
    { grammar => __PACKAGE__ }
)->code;

*parse = Pugs::Compiler::Token->compile( q(
    <?ws>? 
    <statements> 
    <?ws>? 
        { return $_[0]{statements}->() }
),
    { grammar => __PACKAGE__ }
)->code;

1;
__END__
