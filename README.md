# VYRO — Nutrição e treino

Aplicação Flutter demonstrativa para nutrição e treino, com interface em português (Portugal) e inglês, tema escuro, claro ou definido pelo sistema.

## Executar

Com o Flutter instalado, a partir da raiz do projeto:

```sh
flutter pub get
flutter run
```

O app usa Português (Portugal) por predefinição, permite trocar para inglês e oferece temas escuro, claro ou do sistema. A galeria Sistema de design está disponível em `/design-system` ou no ecrã Perfil.

## Estado

- Diário nutricional: adicionar, editar e eliminar alimentos em SQLite local; os valores são calculados por porção a partir dos nutrientes por 100 g e os campos desconhecidos ficam desconhecidos.
- Leitor EAN-8/EAN-13/UPC-A para Android e iOS; consulta explícita à Open Food Facts, cache local, atribuição e entrada manual sem câmara. No Web, o código é introduzido manualmente.
- Planos de treino editáveis, catálogo de exercícios, registo local de séries, temporizador de descanso, retoma de sessões e histórico são funcionais.
- O progresso apresenta sessões, volume de treino e medições de peso guardados neste dispositivo. As medições de peso são introduzidas pelo utilizador.
- Reconhecimento de pratos por fotografia usa um classificador LiteRT local; mostra hipóteses, pede confirmação e não estima porções. A confirmação oferece quatro alimentos simples de uma referência USDA local, com fonte guardada no registo; não infere ingredientes de pratos. Modelo e mapa de etiquetas: Apache 2.0; limitações em `assets/models/NOTICE.md`.
- Análise local de movimento suporta agachamentos: pede acesso à câmara após um toque, apresenta pontos e conta repetições aproximadas. Não grava vídeo nem avalia técnica ou segurança.
- O dashboard soma os registos reais do dia e usa objetivos editáveis do perfil local; valores de nutrientes em falta continuam assinalados como incompletos.
- Perfil (atividade, preferência alimentar, experiência, equipamento e dias), idioma (Português/English), tema (escuro/claro/sistema) e objetivos são guardados localmente. É possível gerar planos segundo equipamento, dias e experiência. A exportação prepara um JSON copiável; a importação restaura uma cópia; a eliminação remove registos, cache e perfil.
- Telemetria e análise de utilização não estão incluídas. O Android desativa o backup automático da aplicação.
- Política de privacidade e rascunho da ficha das lojas: `docs/PRIVACY_POLICY.md` e `docs/STORE_LISTING.md`.
- A especificação, tokens e guia visual permanecem em `docs/` e `brand/`.
