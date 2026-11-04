# Política de segurança

Este aplicativo foi projetado para manutenção assistida de computadores Windows, não para remoção completa de malware ou restauração de arquivos perdidos.

## Relatar falhas

Use o recurso **Report a vulnerability** da aba Security do repositório, quando disponível, para compartilhar relatos de forma privada. Se indisponível, abra um issue **sem** informações de exploração, credenciais, dados pessoais, tokens ou logs de clientes; solicite um canal privado antes de enviar detalhes.

Inclua versão, Windows/PowerShell usados, passos para reproduzir com arquivos descartáveis e impacto esperado.

## Limites de segurança

- A interface 4.x só apaga arquivos previamente analisados em raízes permitidas, após confirmação.
- Não modifica Registro, serviços, firewall, rede, memória virtual ou logs.
- Não envia relatórios ou dados da máquina para servidores.
- A exclusão é permanente: revisar a prévia e possuir backup é obrigatório.
- Não execute scripts recebidos de terceiros sem revisão e verificação de integridade.
- O console legado é separado e contém comandos de alto impacto; não execute em modo automático ou ambiente de produção sem auditoria.
- Os relatórios podem conter nomes de cliente, observações e dados do equipamento: armazene-os em local apropriado.

A validação de segurança ocorre em arquivos de teste temporários, sem afetar o sistema do executor.
