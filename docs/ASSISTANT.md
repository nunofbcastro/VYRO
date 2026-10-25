# Assistente no dispositivo

O assistente responde a perguntas de nutrição e treino **sem Internet e sem
API paga**. Primeiro tenta respostas determinísticas, calculadas no código a
partir dos dados locais. Só quando nenhuma se aplica usa o modelo de linguagem
incluído no sistema operativo. A app não traz modelo próprio, não usa chave de
API e não faz inferência na cloud.

## Modelo de linguagem do sistema (quando disponível)

| Plataforma | Modelo | Requisitos | Código |
| --- | --- | --- | --- |
| iOS | Apple Intelligence (Foundation Models framework) | iOS 26+, iPhone compatível com Apple Intelligence, ativado | `ios/Runner/AppDelegate.swift` (`OnDeviceLlm`); cria uma sessão por pedido |
| Android | Gemini Nano via ML Kit GenAI Prompt API / AICore (`com.google.mlkit:genai-prompt`) | Android 8+ (minSdk 26), dispositivo com AICore, bootloader bloqueado | `android/.../llm/OnDeviceLlmChannel.kt` |
| Web / desktop / outros telemóveis | nenhum | n/a | Mostra o cartão "indisponível" |

Dart fala com as duas plataformas através de um canal, `vyro/on_device_llm`,
com três métodos: `status`, `download` e `generate`. O wrapper é
`lib/core/ai/on_device_llm.dart`.

## Ordem de resposta

1. **Respostas locais** — `answerLocally` (`lib/features/assistant/domain/local_assistant.dart`).
   Não precisam de modelo e funcionam em qualquer dispositivo:
   - **Macros que faltam hoje**: kcal, proteína, hidratos e gordura em falta face
     às metas. Se algum nutriente do diário for desconhecido, a resposta diz que
     os totais são parciais.
   - **Jantar de ontem**: o que foi registado como jantar.
   - **Última série**: resumo local da última análise de movimento (ver `docs/MOTION_ENGINE.md`).
   - **Próximo treino**: nome, dia e exercícios planeados.
   - **Sugestão de refeição**: uma proposta fixa da base (proteína, arroz, legume),
     filtrada pela opção alimentar. Os valores são calculados a partir da base
     (`resolveMeal`); itens sem correspondência ficam por resolver e os totais
     são marcados como parciais.
   - Se nada corresponder, a resposta local é `null` e segue para o passo 2.
2. **Modelo do sistema** — só se `status == available`. Recebe um prompt com
   regras de segurança, o contexto local e as últimas 6 mensagens.
3. **Texto de ajuda** — se o modelo não estiver disponível, falhar ou não houver
   resposta útil.

Nenhuma resposta local escreve no diário. Registar uma sugestão exige confirmação.

## Contexto (`AssistantContext`)

Construído só com dados do dispositivo (`assistant_page.dart`):

- objetivo; metas e valores de hoje de kcal, proteína, hidratos e gordura;
- **opção alimentar** confirmada no perfil (ex.: vegan, vegetariano); a restrição
  também filtra as respostas locais e as propostas do modelo (`foodFitsDiet`);
- alimentos de hoje com gramas (até 10) e indicação de **totais parciais** quando
  há nutrientes desconhecidos;
- plano, próximo treino e exercícios, progresso semanal;
- jantar de ontem e última série observada;
- **preferências confirmadas** pelo utilizador (até 20), tratadas como dados e não
  como instruções.

Dados desconhecidos não são preenchidos. Por exemplo, o prompt instrui o modelo
a não tratar a falta de informação sobre alergias como "sem alergias". Não há
um campo de alergias no contexto.

## Validação dos números

Os números que aparecem no chat vêm sempre de código local, nunca do texto do
modelo. A lógica está em `lib/features/assistant/domain/`:

- `meal_math.dart` — resolve cada item da proposta contra a base offline
  (`FoodDatabase`) e calcula kcal, proteína, hidratos e gordura. `ResolvedMeal`
  guarda, por item, o alimento usado, as alternativas e se falta confirmar.
- `model_answer.dart` — `composeModelAnswer` / `answerFromModel` recebem a
  resposta bruta do modelo (que pode ser um fake em testes) e devolvem o texto a
  mostrar, o cartão e os avisos.
- `prose_numbers.dart` — `checkProseNumbers` verifica os números do texto livre.

Regras:

- **Cartão da refeição**: cada linha mostra o alimento da base, a quantidade e os
  valores calculados. Um item sem correspondência fica "sem valores na base" e os
  totais dizem "Valores parciais — resolve os alimentos".
- **Ambiguidade**: quando um nome corresponde a vários alimentos com pontuação
  próxima (ex.: "Café" sem qualificativo), o cartão mostra "Também pode ser: …" e
  o item fica "a confirmar". Um nome com correspondência exata não gera alternativas.
- **Sem / com**: "sem X" é um pedido de exclusão. Um alimento que contém X nunca
  é escolhido para "sem X" (e o inverso). Se a base não indica a exclusão, o item
  fica "a confirmar". Um nome com palavras que a entrada da base não tem
  (ex.: "Frango com arroz") não é associado silenciosamente ao frango.
- **Texto do modelo**: o prompt pede que o modelo não escreva kcal, proteína,
  hidratos ou gordura. Como garantia, cada linha com uma palavra de nutriente e um
  número é mantida só se o número coincidir com os totais locais: até 15 kcal ou
  10 % (o menor), e até 2 g ou 10 % (o menor, com mínimo de 1 g). Caso contrário
  a linha é removida; sem totais completos, nenhuma linha com números nutricionais
  é mantida. Uma nota diz "Valores calculados pela VYRO a partir da base local" e
  outra diz quando frases foram removidas. Sem números nutricionais, o texto fica
  igual. A remoção é por linha, sem reescrever texto livre.
- Propostas com alimentos que violam a opção alimentar são recusadas com uma
  mensagem a pedir outra sugestão.
- O registo no diário (`meal_log_sheet.dart`) usa a mesma correspondência do
  cartão (`matchFood`); o utilizador pode trocar o alimento na revisão.

## Memória local: "O que a VYRO sabe sobre ti"

Ecrã `lib/features/assistant/local_intelligence_page.dart`, aberto pelo ícone
de livro no diário de Nutrição e pelo botão do assistente.

- **Preferências**: só o que o utilizador escreve. Podes adicionar, editar e
  apagar (até 20, 240 caracteres cada). O assistente não cria memórias sozinho.
- **Receitas habituais**: receitas com peso final cozinhado e registo de porções
  (ver `docs/NUTRITION_DATA.md`).
- **Aprender com correções**: ordena sugestões de alimentos na fotografia a partir
  das escolhas anteriores. Pode ser desligado e apagado. Nunca confirma um alimento
  por si nem guarda fotografias (ver `docs/FOOD_VISION.md`).
- **Qualidade e esforço**: contadores locais (fotos revistas, correções, respostas
  úteis ou não, tempo de revisão, contagens de movimento). Não há imagens nem
  mensagens, e não medem precisão clínica ou nutricional. Podem ser apagados.

Tudo fica em preferências locais (`assistant_memory_v1`, `food_corrections_v1`,
`recipes_v1`, `quality_metrics_v1`). É incluído na exportação JSON; a importação
valida cada bloco antes de substituir os dados atuais; "Apagar todos os dados"
remove-o.

## Privacidade

- A conversa fica só em memória no ecrã. Sair do ecrã limpa-a e não é guardada.
- Nenhum dado é enviado para fora do dispositivo pelo assistente.
- O modelo recebe apenas o prompt montado localmente.

## Experimental

- O ecrã é marcado **EXPERIMENTAL** e cada resposta do modelo indica que foi
  gerada no dispositivo e que os valores da refeição foram validados à parte.
- As respostas locais são cálculos determinísticos sobre dados do utilizador,
  mas não são aconselhamento médico nem substituem um profissional de saúde.

## Pontos de entrada

- O ícone ✨ no topo de Início.
- Perfil → Assistente.
- Ícone de livro em Nutrição (memória e receitas).

## Limites

- Respostas do modelo podem estar erradas; a interface avisa.
- Só os dispositivos com o modelo do sistema recebem respostas do modelo. Os
  outros continuam a ter as respostas locais.
- Sem streaming. Enquanto um pedido está em curso, o envio fica bloqueado; a
  resposta só é mostrada se corresponder ao pedido atual (`_requestId`).
- O histórico do modelo é de 6 mensagens, sem orçamento de tokens.
- O formato `[[MEAL]]` é texto livre validado pela app, não saída estruturada.
- Ainda não há leitura do resumo de uma análise de vídeo nem de uma fotografia no chat.
