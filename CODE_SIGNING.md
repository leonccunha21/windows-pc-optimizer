# Política de assinatura de código

## Assinatura gratuita (SignPath Foundation)

Free code signing provided by SignPath.io, certificate by SignPath Foundation.

O PC Optimizer está preparando a candidatura ao programa gratuito do SignPath Foundation para projetos open source. Após a aprovação, os executáveis de release serão assinados via SignPath; até lá, os pacotes locais usam certificado self-signed apenas para integridade de desenvolvimento.

## Repositório oficial

- Repositório: `https://github.com/leonccunha21/windows-pc-optimizer`
- Licença: MIT (OSI-approved)
- Build: GitHub Actions em agentes hospedados, a partir do código-fonte público.
- Artefato assinado: `PC-Optimizer.exe` dentro do pacote `PC-Optimizer-Portable-<versão>.zip`.

## Papéis e aprovação

- Committers/revisores: mantenedor(es) com acesso de escrita ao repositório.
- Aprovadores: mantenedor(es) que aprovam a tag de release e o pedido de assinatura no SignPath.
- Todos os membros com acesso ao repositório e ao SignPath usam MFA.

## Privacidade

Este programa não transfere informações para redes não especificadas pelo usuário. Diagnósticos são locais; testes de DNS/TCP só ocorrem após autorização explícita do usuário. Consulte `SECURITY.md`.

## Processo de release

1. Push de tag `v*`.
2. CI valida sintaxe, testes, WPF e pacote portátil.
3. Build gera o pacote não assinado.
4. Pedido de assinatura é enviado ao SignPath (quando configurado) e aprovado manualmente.
5. O executável assinado substitui o não assinado, o ZIP é regenerado e o SHA-256 é calculado.
6. Release publicada no GitHub com ZIP e `.sha256`.

## Secrets/vars necessários após aprovação

- `SIGNPATH_API_TOKEN` (secret)
- `SIGNPATH_ORGANIZATION_ID` (variable)
- `SIGNPATH_PROJECT_SLUG` (variable)
- `SIGNPATH_SIGNING_POLICY_SLUG` (variable)
- `SIGNPATH_ARTIFACT_CONFIGURATION_SLUG` (variable, opcional)
