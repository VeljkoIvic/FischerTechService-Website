--Aufgabe 19--
Begründung & Änderungen (Bulma via SCSS / npm)

Bulma wurde über npm eingebunden, um eine lokale,
versionierte und flexibel anpassbare Lösung ohne CDN-Abhängigkeit zu nutzen.
Dadurch ist individuelles Theming über Sass-Variablen möglich und der Build bleibt offline-fähig.

Zur Umsetzung wurde eine Sass-Pipeline mit sass und sass-embedded eingerichtet.
Das zentrale Styling erfolgt nun über style.scss,
welche Bulma importiert und die bestehenden Projektfarben sowie Custom-Styles integriert.
Alte CSS- und CDN-Imports wurden entfernt und durch SCSS-Imports auf den Seiten ersetzt.
