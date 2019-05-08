# Cuttie
Сними - обрежь - поделись!

# Задачи

[v] Запись видео
[v] Обрезка видео
[v] Просмотр библиотеки записанного\обрезанного
[v] Шаринг видео в соцсети

# UI

UI взят по образу приложений камер на различный андроид девайсах
содержит 3 экрана:

1. Экран с возможностью записи видео
2. Экран просмотра и редактирвания видео
3. экран просмотра библиотеки видео

Практически линейная навигация по экранам
Возможные перреходы

[1] -> [2] -> [3] -> [2] -> [1]

[1] -> [2] -(переход на отредактированое видео)-> [2] -> [1]

# Немного о реализации

## Запись видео

Реализованно стандартной flutter библиотекой camera

## Обрезка видео

Реализованна с использованием либо библиотеки ffmpeg либо стандартным android (для API 18+) MediaCodec API.
Есть возможность выбирать каким кодеком пользоваться (в коде) плюс можно подключить любую другую библиотеку без необходимости менять большие участки кода для этого подключенная библиотека должна реализовывать интерфей, простите абстрактный класс ))) Editor.

## Method Channels

достаточно много используются платформенные вызовы, а именнно пришлось с помошью них организовать: 

- редактироание видео (по требованию)
- генерацию миниатюр
- отправку видео в соцсети

## Отправка в соцсети и хранение видео

К сожалению flutter из коробки не умеет делать шаринг в соцсети чего либо отличного от простого текста по этому это делается при помощи платформенного вызова, также есть один нюанс связанный с использованием внутреннего хранилища для хранение библиотеки видео. 

в flutter-е мы получаем доступ к внутреннему хранилищу приложения через метод ```getApplicationDocumentsDirectory()``` но к файлом этой папки мы не можем получить доступ через ```androidx.core.content.FileProvider``` по этому мы сначала копируем файл в папку кэша и шарим оттуда.

## :(((

Конечно в условия того что это было написанно в достаточно сжатые сроки работает не идеально. из того чего хотелось но не успелось
покрытие тестами и локализация. ну и есть чего подрефакторить конечно.

дурацкая вещь то что написалось всё это буквально за один присесит по этому я даже забыл проинициализоровать гит репозиторий )))) 

по этому всё это и будет инит коммитом, сам поражаюсь как так ))) ну.. это.. бывает..



