@{
    # Regras desativadas com justificativa (domínio e compatibilidade com o legado).
    ExcludeRules = @(
        'PSUseApprovedVerbs'                          # Clean-/Optimize-/Repair- são nomes de domínio consolidados.
        'PSUseSingularNouns'                          # Categorias no plural são mais claras para o usuário.
        'PSAvoidUsingWriteHost'                       # O console legado é interativo por natureza.
        'PSAvoidOverwritingBuiltInCmdlets'            # Write-Log é função do projeto, não substitui cmdlet padrão.
        'PSUseShouldProcessForStateChangingFunctions' # UI/test helpers; funções destrutivas têm ShouldProcess explícito.
        'PSReviewUnusedParameter'                     # Parâmetros do legado são consumidos por funções via escopo global.
    )
    Severity = @('Error', 'Warning')
}
