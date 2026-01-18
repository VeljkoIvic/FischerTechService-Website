--Aufgabe 21--
Shadow-Mixin

Fragen:
Nutzt die Definition vom Tag 6 für Drop Shadows. Könnt ihr Drop Shadows als Mixin definieren? Könnt ihr die Breite des Shadows als Argument ins Mixin geben, damit jede Box unterschiedliche Shadows haben können?
Für Fortgeschrittene: Kann man auch einen Default-Wert definieren, damit der Shadow normalerweise immer gleich aussieht?


Antwort:
Ja, Drop Shadows können als SCSS-Mixin definiert werden. Dafür wurde ein Mixin erstellt, das den box-shadow zentral kapselt.
Die Breite des Shadows wird dabei als Argument übergeben, sodass verschiedene Elemente unterschiedliche Schattenstärken verwenden können.

Zusätzlich wurde ein Default-Wert für den Blur definiert, sodass ohne Angabe eines Parameters immer ein einheitlicher Standard-Shadow verwendet wird.
Für Hover-Zustände kann eine verstärkte Variante des Mixins genutzt werden, wodurch konsistente und skalierbare Schatteneffekte entstehen.