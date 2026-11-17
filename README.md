# Tapa-Buraco Online — Boituva

Plataforma web em desenvolvimento para registro, consulta e acompanhamento de solicitações relacionadas a buracos e problemas no pavimento urbano de Boituva (SP).

Este repositório contém uma **adaptação do FixMyStreet Platform**, software livre originalmente desenvolvido pela [mySociety](https://www.mysociety.org/). A proposta desta versão é estudar e adaptar a plataforma para um fluxo de atendimento municipal, com interface em português e identidade visual voltada ao contexto de Boituva.

> **Status do projeto:** desenvolvimento e adaptação. Este repositório é um projeto independente e experimental. Não representa, por si só, um sistema oficial da Prefeitura de Boituva, não implica parceria ou aprovação institucional e não substitui os canais oficiais de atendimento.

---

## Sobre o projeto

O Tapa-Buraco Online busca facilitar o registro de problemas no pavimento urbano, permitindo que o cidadão informe a localização da ocorrência e forneça detalhes que ajudem na identificação do local.

A iniciativa pretende apoiar a organização das solicitações e o trabalho de análise e encaminhamento pela equipe responsável, reduzindo a dependência de registros dispersos e facilitando a consulta do histórico de cada ocorrência.

### Objetivos

- Facilitar o registro de ocorrências relacionadas a buracos e danos no pavimento.
- Permitir a identificação geográfica do local informado.
- Possibilitar o envio de descrição e fotografia para contextualizar a solicitação.
- Apoiar a consulta e a organização das ocorrências pela equipe administrativa.
- Criar uma base que possa evoluir para fluxos de triagem, acompanhamento e prestação de informações.

## Origem e relação com o FixMyStreet

O projeto utiliza como base o **[FixMyStreet Platform](https://github.com/mysociety/fixmystreet)**, uma plataforma de código aberto criada pela organização [mySociety](https://www.mysociety.org/) para permitir que comunidades registrem problemas em espaços públicos e encaminhem essas informações às autoridades responsáveis.

O Tapa-Buraco Online não é o produto original da mySociety. É um fork com adaptações próprias, conduzidas neste repositório para atender ao contexto brasileiro e, inicialmente, ao cenário de Boituva (SP).

As alterações e os componentes específicos desta adaptação devem ser considerados em conjunto com os arquivos, avisos de direitos autorais e licenças dos respectivos componentes.

- **Projeto original:** [mysociety/fixmystreet](https://github.com/mysociety/fixmystreet)
- **Organização responsável pelo projeto original:** [mySociety](https://www.mysociety.org/)
- **Documentação oficial:** [fixmystreet.org](https://fixmystreet.org/)
- **Repositório desta adaptação:** [vktorvini/Tapa-Buraco-Online](https://github.com/vktorvini/Tapa-Buraco-Online)

## Escopo da adaptação para Boituva

A adaptação está sendo desenvolvida gradualmente. Entre as frentes de trabalho estão:

- Localização e tradução da interface para português do Brasil (pt_BR).
- Personalização visual e contextualização para Boituva.
- Configuração de identidade visual própria para a adaptação.
- Adequação dos textos, categorias e fluxos ao registro de ocorrências de buracos.
- Estruturação de recursos administrativos para consulta e análise das solicitações.

O escopo poderá ser ampliado futuramente para outras categorias de zeladoria urbana. Integrações com sistemas municipais, encaminhamento automático, notificações e fluxos oficiais dependem de desenvolvimento, configuração e eventual autorização dos responsáveis pelos respectivos sistemas. **Não considere essas integrações disponíveis apenas por estarem descritas como objetivos.**

## Tecnologias

A plataforma original e esta adaptação utilizam, entre outras dependências do projeto:

- **Perl** e framework **Catalyst** — aplicação web.
- **PostgreSQL** — banco de dados.
- **Memcached** — cache.
- **Nginx** — servidor web/proxy.
- **Docker e Docker Compose** — ambiente de desenvolvimento e execução.
- **OpenLayers** — recursos de mapas, conforme a configuração da aplicação.

Consulte os arquivos de configuração do repositório para identificar as versões e dependências efetivamente utilizadas no ambiente.

## Executar em ambiente local

### Pré-requisitos

- Git.
- Docker Desktop com integração WSL 2 (Windows) ou Docker Engine.
- Docker Compose.

### Clonar o repositório

    git clone https://github.com/vktorvini/Tapa-Buraco-Online.git
    cd Tapa-Buraco-Online

### Iniciar o ambiente de desenvolvimento

Na configuração de desenvolvimento utilizada neste repositório:

    docker compose -p tapa-buraco-dev -f docker/docker-compose-dev.yml up -d

Para conferir os serviços:

    docker compose -p tapa-buraco-dev -f docker/docker-compose-dev.yml ps

A porta de acesso pode variar conforme o mapeamento definido nos arquivos Docker Compose. No ambiente local de desenvolvimento, verifique a URL e a porta configuradas para a aplicação.

> Este procedimento descreve o ambiente de desenvolvimento. Uma implantação em servidor exige configuração própria de segurança, domínio, HTTPS, persistência de dados, backups, variáveis de ambiente e serviços de produção. Não utilize configurações de desenvolvimento diretamente em produção.

## Direitos autorais e licença

### Licença do software

O projeto original FixMyStreet é distribuído sob os termos da **GNU Affero General Public License, versão 3 ou, a critério do usuário, qualquer versão posterior (AGPL-3.0-or-later)**, conforme o arquivo LICENSE.txt mantido no repositório.

A AGPL é uma licença de software livre com cláusula de copyleft. Em termos gerais, ela permite executar, estudar, modificar e redistribuir o software, inclusive em atividades comerciais, desde que sejam respeitadas suas condições.

Entre as principais obrigações relevantes para este projeto estão:

1. **Preservar avisos:** manter os avisos de direitos autorais, referências à licença e demais avisos legais aplicáveis.
2. **Identificar modificações:** versões modificadas devem indicar de forma clara que foram alteradas e informar a data das modificações.
3. **Manter a licença:** a distribuição de uma obra derivada abrangida pela AGPL deve respeitar os termos da licença.
4. **Disponibilizar o código-fonte:** quando uma versão modificada é utilizada para oferecer interação a usuários por meio de uma rede, a seção 13 da AGPL exige oferecer a esses usuários acesso ao código-fonte correspondente da versão em execução, sem cobrança, por meio adequado.
5. **Não retirar créditos de terceiros:** componentes e dependências podem possuir avisos e licenças próprios, que também devem ser respeitados.

A licença não significa que o software seja de domínio público, nem transfere automaticamente a autoria do FixMyStreet para quem realiza uma adaptação.

### Autoria e atribuição

- O **FixMyStreet Platform** é um projeto da mySociety, com os direitos autorais indicados no arquivo de licença original.
- O **Tapa-Buraco Online — Boituva** é uma adaptação independente mantida neste repositório.
- As contribuições originais feitas especificamente para esta adaptação devem ser identificadas como modificações deste projeto, sem apagar ou substituir os créditos e avisos do software de origem.
- Marcas, nomes, logotipos, mapas, bibliotecas e demais materiais de terceiros continuam sujeitos aos direitos e termos de seus respectivos titulares.

Para consultar os termos completos, leia o arquivo [LICENSE.txt](./LICENSE.txt) incluído neste repositório e a [licença AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html).

> Este texto é uma explicação informativa e não substitui a leitura da licença completa nem constitui parecer jurídico. Em caso de implantação institucional ou distribuição a terceiros, recomenda-se revisar a conformidade da aplicação, das dependências e dos avisos exibidos aos usuários.

## Contribuições

Sugestões, correções e melhorias podem ser discutidas por meio das Issues e Pull Requests deste repositório. Ao contribuir, verifique a licença aplicável e preserve os avisos de autoria e atribuição dos componentes utilizados.

## Referências

- [FixMyStreet Platform — repositório original](https://github.com/mysociety/fixmystreet)
- [mySociety — organização responsável pelo projeto original](https://www.mysociety.org/)
- [Documentação oficial do FixMyStreet](https://fixmystreet.org/)
- [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html)

---

**Tapa-Buraco Online — Boituva**  
Adaptação independente do FixMyStreet Platform, em desenvolvimento.
