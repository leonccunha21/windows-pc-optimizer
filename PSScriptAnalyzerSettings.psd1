@{
    # Advisory analysis; only concrete security/style rules are included at first.
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSUseApprovedVerbs'
        'PSAvoidUsingCmdletAliases'
    )
    Severity = @('Warning', 'Error')
}
