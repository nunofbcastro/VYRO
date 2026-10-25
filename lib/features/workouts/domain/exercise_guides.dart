/// Short how-to notes for each catalogue exercise: steps, one cue and one
/// common mistake. General technique guidance, not individual coaching.
class ExerciseGuide {
  const ExerciseGuide({
    required this.stepsPt,
    required this.stepsEn,
    required this.tipPt,
    required this.tipEn,
    required this.mistakePt,
    required this.mistakeEn,
  });

  final List<String> stepsPt;
  final List<String> stepsEn;
  final String tipPt;
  final String tipEn;
  final String mistakePt;
  final String mistakeEn;

  List<String> steps(bool english) => english ? stepsEn : stepsPt;
  String tip(bool english) => english ? tipEn : tipPt;
  String mistake(bool english) => english ? mistakeEn : mistakePt;
}

ExerciseGuide? guideFor(String key) => exerciseGuides[key];

/// Muscle group label for catalogue `muscleGroup` values.
String muscleLabel(String group, {required bool english}) {
  const pt = {
    'legs': 'Pernas',
    'chest': 'Peito',
    'back': 'Costas',
    'glutes': 'Glúteos',
    'core': 'Core',
    'shoulders': 'Ombros',
    'hamstrings': 'Posteriores',
    'arms': 'Braços',
  };
  const en = {
    'legs': 'Legs',
    'chest': 'Chest',
    'back': 'Back',
    'glutes': 'Glutes',
    'core': 'Core',
    'shoulders': 'Shoulders',
    'hamstrings': 'Hamstrings',
    'arms': 'Arms',
  };
  return (english ? en : pt)[group] ?? group;
}

const exerciseGuides = <String, ExerciseGuide>{
  'goblet_squat': ExerciseGuide(
    stepsPt: [
      'Segura o halter junto ao peito, cotovelos para baixo.',
      'Pés à largura dos ombros, pontas ligeiramente para fora.',
      'Desce como se te sentasses, peito alto, até onde controlas.',
      'Empurra o chão com o pé inteiro para subir.',
    ],
    stepsEn: [
      'Hold the dumbbell at your chest, elbows pointing down.',
      'Feet shoulder-width apart, toes slightly out.',
      'Sit down between your hips, chest up, as deep as you control.',
      'Drive through the whole foot to stand.',
    ],
    tipPt: 'Joelhos acompanham a direção dos pés.',
    tipEn: 'Knees track in line with your toes.',
    mistakePt: 'Levantar os calcanhares ou arredondar as costas no fundo.',
    mistakeEn: 'Heels lifting or the back rounding at the bottom.',
  ),
  'dumbbell_press': ExerciseGuide(
    stepsPt: [
      'Deita-te no banco com um halter em cada mão, pés no chão.',
      'Omoplatas juntas e para baixo.',
      'Desce os halteres até ao lado do peito, cotovelos a ~45°.',
      'Empurra para cima sem bater os halteres.',
    ],
    stepsEn: [
      'Lie on the bench with a dumbbell in each hand, feet on the floor.',
      'Squeeze your shoulder blades together and down.',
      'Lower the dumbbells beside your chest, elbows at ~45°.',
      'Press up without clanking the dumbbells.',
    ],
    tipPt: 'Desce em 2–3 segundos, sobe com força.',
    tipEn: 'Lower in 2–3 seconds, press with intent.',
    mistakePt: 'Abrir os cotovelos a 90° e sobrecarregar os ombros.',
    mistakeEn: 'Flaring elbows to 90° and loading the shoulders.',
  ),
  'seated_row': ExerciseGuide(
    stepsPt: [
      'Senta-te com o tronco direito e os joelhos ligeiramente fletidos.',
      'Puxa a pega até ao abdómen levando os cotovelos para trás.',
      'Aperta as omoplatas no final.',
      'Estende os braços devagar sem perder a postura.',
    ],
    stepsEn: [
      'Sit tall with knees slightly bent.',
      'Pull the handle to your stomach, driving the elbows back.',
      'Squeeze your shoulder blades at the end.',
      'Extend the arms slowly without slumping.',
    ],
    tipPt: 'Pensa em puxar com os cotovelos, não com as mãos.',
    tipEn: 'Think of pulling with the elbows, not the hands.',
    mistakePt: 'Balançar o tronco para trás para mover o peso.',
    mistakeEn: 'Swinging the torso back to move the weight.',
  ),
  'glute_bridge': ExerciseGuide(
    stepsPt: [
      'Deitado de costas, joelhos fletidos e pés à largura da anca.',
      'Contrai o abdómen e os glúteos.',
      'Sobe a anca até formar uma linha ombros–joelhos.',
      'Pausa 1 segundo em cima e desce com controlo.',
    ],
    stepsEn: [
      'Lie on your back, knees bent, feet hip-width apart.',
      'Brace your core and squeeze your glutes.',
      'Lift your hips into a line from shoulders to knees.',
      'Pause for 1 second at the top, lower with control.',
    ],
    tipPt: 'Empurra pelos calcanhares.',
    tipEn: 'Drive through your heels.',
    mistakePt: 'Arquear a lombar em vez de usar os glúteos.',
    mistakeEn: 'Arching the lower back instead of using the glutes.',
  ),
  'plank': ExerciseGuide(
    stepsPt: [
      'Antebraços no chão, cotovelos por baixo dos ombros.',
      'Corpo em linha reta da cabeça aos calcanhares.',
      'Contrai abdómen e glúteos e respira normalmente.',
      'Mantém o tempo indicado (as "reps" são segundos).',
    ],
    stepsEn: [
      'Forearms on the floor, elbows under the shoulders.',
      'Body in a straight line from head to heels.',
      'Brace your abs and glutes and breathe normally.',
      'Hold for the target time ("reps" are seconds).',
    ],
    tipPt: 'Puxa o umbigo para dentro sem prender a respiração.',
    tipEn: 'Draw your belly in without holding your breath.',
    mistakePt: 'Deixar a anca descair ou subir demasiado.',
    mistakeEn: 'Letting the hips sag or pike up.',
  ),
  'split_squat': ExerciseGuide(
    stepsPt: [
      'Um pé à frente e outro atrás, como num passo largo.',
      'Desce na vertical até o joelho de trás quase tocar o chão.',
      'O tronco fica direito e o peso no pé da frente.',
      'Sobe empurrando o pé da frente; troca de perna no fim.',
    ],
    stepsEn: [
      'One foot forward, one back, like a long stride.',
      'Lower straight down until the back knee nearly touches the floor.',
      'Keep the torso upright and weight on the front foot.',
      'Push through the front foot; switch legs at the end.',
    ],
    tipPt: 'Usa uma parede para equilíbrio se precisares.',
    tipEn: 'Use a wall for balance if needed.',
    mistakePt: 'Passada demasiado curta, com o joelho muito à frente.',
    mistakeEn: 'Stance too short, knee driving far forward.',
  ),
  'shoulder_press': ExerciseGuide(
    stepsPt: [
      'Halteres à altura dos ombros, palmas para a frente.',
      'Contrai o abdómen e os glúteos.',
      'Empurra para cima até os braços quase esticarem.',
      'Desce devagar até à altura do queixo.',
    ],
    stepsEn: [
      'Dumbbells at shoulder height, palms forward.',
      'Brace your abs and glutes.',
      'Press overhead until the arms are nearly straight.',
      'Lower slowly to chin height.',
    ],
    tipPt: 'Mantém as costelas "fechadas" para não arquear.',
    tipEn: 'Keep your ribs down so you do not arch.',
    mistakePt: 'Arquear muito a lombar para empurrar.',
    mistakeEn: 'Over-arching the lower back to press.',
  ),
  'lat_pulldown': ExerciseGuide(
    stepsPt: [
      'Agarra a barra um pouco mais aberto que os ombros.',
      'Inclina ligeiramente o tronco para trás, peito alto.',
      'Puxa a barra até ao topo do peito levando os cotovelos para baixo.',
      'Sobe a barra com controlo até esticar os braços.',
    ],
    stepsEn: [
      'Grip the bar slightly wider than your shoulders.',
      'Lean back slightly, chest up.',
      'Pull the bar to your upper chest, elbows driving down.',
      'Let it rise with control to full arm extension.',
    ],
    tipPt: 'Começa o movimento baixando os ombros.',
    tipEn: 'Start each rep by pulling the shoulders down.',
    mistakePt: 'Puxar a barra para trás da cabeça.',
    mistakeEn: 'Pulling the bar behind the neck.',
  ),
  'hip_hinge': ExerciseGuide(
    stepsPt: [
      'Halteres à frente das coxas, joelhos ligeiramente fletidos.',
      'Leva a anca para trás mantendo as costas neutras.',
      'Desce os halteres junto às pernas até sentir os posteriores.',
      'Volta a subir empurrando a anca para a frente.',
    ],
    stepsEn: [
      'Dumbbells in front of your thighs, knees softly bent.',
      'Push your hips back, keeping a neutral spine.',
      'Slide the dumbbells down your legs until you feel the hamstrings.',
      'Stand up by driving the hips forward.',
    ],
    tipPt: 'Imagina fechar uma porta com o rabo.',
    tipEn: 'Imagine closing a door behind you with your hips.',
    mistakePt: 'Arredondar as costas ou agachar em vez de dobrar a anca.',
    mistakeEn: 'Rounding the back or squatting instead of hinging.',
  ),
  'dead_bug': ExerciseGuide(
    stepsPt: [
      'De costas, braços para cima e joelhos a 90°.',
      'Encosta a lombar ao chão.',
      'Estende braço e perna opostos devagar.',
      'Volta ao centro e troca de lado.',
    ],
    stepsEn: [
      'On your back, arms up, knees at 90°.',
      'Press your lower back into the floor.',
      'Slowly extend the opposite arm and leg.',
      'Return to centre and switch sides.',
    ],
    tipPt: 'Expira enquanto estendes.',
    tipEn: 'Breathe out as you extend.',
    mistakePt: 'A lombar descolar do chão.',
    mistakeEn: 'Lower back lifting off the floor.',
  ),
  'push_up': ExerciseGuide(
    stepsPt: [
      'Mãos um pouco mais abertas que os ombros.',
      'Corpo em linha reta, abdómen contraído.',
      'Desce o peito até perto do chão, cotovelos a ~45°.',
      'Empurra o chão para subir.',
    ],
    stepsEn: [
      'Hands slightly wider than your shoulders.',
      'Body in a straight line, core braced.',
      'Lower your chest close to the floor, elbows at ~45°.',
      'Push the floor away to rise.',
    ],
    tipPt: 'Se for difícil, apoia os joelhos ou as mãos num banco.',
    tipEn: 'If hard, use your knees or a bench for your hands.',
    mistakePt: 'Anca a descair ou cabeça a ir à frente.',
    mistakeEn: 'Hips sagging or the head leading.',
  ),
  'side_plank': ExerciseGuide(
    stepsPt: [
      'De lado, antebraço no chão por baixo do ombro.',
      'Pernas esticadas, pés um sobre o outro.',
      'Sobe a anca até o corpo ficar em linha.',
      'Mantém o tempo indicado e troca de lado.',
    ],
    stepsEn: [
      'On your side, forearm under the shoulder.',
      'Legs straight, feet stacked.',
      'Lift your hips until the body is in line.',
      'Hold for the target time, then switch sides.',
    ],
    tipPt: 'Versão mais fácil: joelhos fletidos no chão.',
    tipEn: 'Easier version: knees bent on the floor.',
    mistakePt: 'Deixar a anca cair para o chão.',
    mistakeEn: 'Letting the hips drop toward the floor.',
  ),
  'reverse_lunge': ExerciseGuide(
    stepsPt: [
      'De pé, dá um passo largo para trás.',
      'Desce até os dois joelhos ficarem a cerca de 90°.',
      'Tronco direito, peso no pé da frente.',
      'Volta à posição inicial empurrando o pé da frente.',
    ],
    stepsEn: [
      'Standing tall, take a long step back.',
      'Lower until both knees are around 90°.',
      'Torso upright, weight on the front foot.',
      'Return by pushing through the front foot.',
    ],
    tipPt: 'Alterna pernas ou faz todas de um lado primeiro.',
    tipEn: 'Alternate legs or do one side first.',
    mistakePt: 'Joelho da frente a cair para dentro.',
    mistakeEn: 'Front knee caving inward.',
  ),
  'dumbbell_row': ExerciseGuide(
    stepsPt: [
      'Apoia uma mão e um joelho num banco, costas planas.',
      'Halter pendurado por baixo do ombro.',
      'Puxa o halter em direção à anca.',
      'Desce devagar até esticar o braço.',
    ],
    stepsEn: [
      'Support one hand and knee on a bench, back flat.',
      'Let the dumbbell hang under the shoulder.',
      'Pull it toward your hip.',
      'Lower slowly to full extension.',
    ],
    tipPt: 'O cotovelo passa rente ao corpo.',
    tipEn: 'Keep the elbow close to your body.',
    mistakePt: 'Rodar o tronco para levantar o peso.',
    mistakeEn: 'Twisting the torso to lift the weight.',
  ),
  'lateral_raise': ExerciseGuide(
    stepsPt: [
      'De pé, halteres ao lado do corpo, cotovelos levemente fletidos.',
      'Eleva os braços de lado até à altura dos ombros.',
      'Pausa breve em cima.',
      'Desce devagar.',
    ],
    stepsEn: [
      'Standing, dumbbells at your sides, elbows slightly bent.',
      'Raise your arms out to shoulder height.',
      'Pause briefly at the top.',
      'Lower slowly.',
    ],
    tipPt: 'Usa pouco peso; a técnica conta mais.',
    tipEn: 'Use light weight; technique matters more.',
    mistakePt: 'Balançar o corpo ou encolher os ombros.',
    mistakeEn: 'Swinging or shrugging the shoulders.',
  ),
  'biceps_curl': ExerciseGuide(
    stepsPt: [
      'De pé, halteres ao lado do corpo, palmas para a frente.',
      'Cotovelos fixos junto ao tronco.',
      'Dobra os braços até aos ombros.',
      'Desce devagar até esticar.',
    ],
    stepsEn: [
      'Standing, dumbbells at your sides, palms forward.',
      'Elbows fixed by your torso.',
      'Curl up toward your shoulders.',
      'Lower slowly to full extension.',
    ],
    tipPt: 'A descida lenta dá mais resultado.',
    tipEn: 'A slow lowering phase gives more results.',
    mistakePt: 'Usar balanço das costas.',
    mistakeEn: 'Using momentum from the back.',
  ),
  'triceps_pushdown': ExerciseGuide(
    stepsPt: [
      'De frente para o cabo, pega à altura do peito.',
      'Cotovelos colados ao corpo.',
      'Estende os braços até ao fim.',
      'Volta devagar até 90°.',
    ],
    stepsEn: [
      'Face the cable, handle at chest height.',
      'Elbows tucked by your sides.',
      'Extend the arms fully.',
      'Return slowly to 90°.',
    ],
    tipPt: 'Só os antebraços se mexem.',
    tipEn: 'Only your forearms move.',
    mistakePt: 'Afastar os cotovelos do corpo.',
    mistakeEn: 'Letting the elbows drift away from the body.',
  ),
  'face_pull': ExerciseGuide(
    stepsPt: [
      'Corda no cabo à altura do rosto.',
      'Puxa em direção à cara, separando as mãos.',
      'Cotovelos altos, omoplatas juntas.',
      'Volta com controlo.',
    ],
    stepsEn: [
      'Rope on the cable at face height.',
      'Pull toward your face, spreading the hands.',
      'Elbows high, shoulder blades together.',
      'Return with control.',
    ],
    tipPt: 'Ótimo para postura e saúde dos ombros.',
    tipEn: 'Great for posture and shoulder health.',
    mistakePt: 'Usar peso a mais e inclinar o tronco.',
    mistakeEn: 'Going too heavy and leaning back.',
  ),
  'pike_push_up': ExerciseGuide(
    stepsPt: [
      'Posição de flexão com a anca alta, em "V" invertido.',
      'Mãos à largura dos ombros.',
      'Baixa a cabeça entre as mãos dobrando os cotovelos.',
      'Empurra de volta à posição inicial.',
    ],
    stepsEn: [
      'Push-up position with hips high, an inverted "V".',
      'Hands shoulder-width apart.',
      'Lower your head between your hands by bending the elbows.',
      'Push back to the start.',
    ],
    tipPt: 'Quanto mais vertical o tronco, mais difícil.',
    tipEn: 'The more vertical your torso, the harder it is.',
    mistakePt: 'Deixar a anca baixar e virar flexão normal.',
    mistakeEn: 'Letting the hips drop into a regular push-up.',
  ),
  'superman': ExerciseGuide(
    stepsPt: [
      'Deitado de barriga para baixo, braços esticados à frente.',
      'Olha para o chão para proteger o pescoço.',
      'Eleva braços e pernas uns centímetros.',
      'Pausa 2 segundos e desce.',
    ],
    stepsEn: [
      'Lie face down, arms stretched forward.',
      'Look at the floor to protect your neck.',
      'Lift arms and legs a few centimetres.',
      'Pause for 2 seconds and lower.',
    ],
    tipPt: 'Movimento pequeno e controlado.',
    tipEn: 'Small, controlled movement.',
    mistakePt: 'Atirar a cabeça para trás.',
    mistakeEn: 'Throwing the head back.',
  ),
  'calf_raise': ExerciseGuide(
    stepsPt: [
      'De pé, pontas dos pés num degrau ou no chão.',
      'Sobe o mais alto possível nas pontas.',
      'Pausa 1 segundo em cima.',
      'Desce devagar, abaixo do degrau se possível.',
    ],
    stepsEn: [
      'Stand with the balls of your feet on a step or the floor.',
      'Rise as high as you can.',
      'Pause for 1 second at the top.',
      'Lower slowly, below the step if possible.',
    ],
    tipPt: 'Apoia uma mão numa parede para equilíbrio.',
    tipEn: 'Hold a wall for balance.',
    mistakePt: 'Repetições rápidas sem amplitude.',
    mistakeEn: 'Fast reps with a short range.',
  ),
  'bird_dog': ExerciseGuide(
    stepsPt: [
      'De quatro, mãos por baixo dos ombros e joelhos por baixo da anca.',
      'Estende braço e perna opostos até à horizontal.',
      'Mantém a anca nivelada e pausa 2 segundos.',
      'Volta e troca de lado.',
    ],
    stepsEn: [
      'On all fours, hands under shoulders, knees under hips.',
      'Extend the opposite arm and leg to horizontal.',
      'Keep the hips level and pause for 2 seconds.',
      'Return and switch sides.',
    ],
    tipPt: 'Imagina um copo de água nas costas.',
    tipEn: 'Imagine a glass of water on your back.',
    mistakePt: 'Rodar a anca ao levantar a perna.',
    mistakeEn: 'Rotating the hips as the leg lifts.',
  ),
};
