# INSTRUCTIONS FOR USING THIS REPOSITORY

In GitHub, files are stored in _repositories_ (often called "repos", for short), which are public and can be viewed by anybody. However, changes to the original files can only be made or approved by the **owners** or contributors to the repositories (after you make a **pull request**, which is a request to have your changes merged with the original).

To obtain a complete carbon-copy of the files in this repository, simply click `download ZIP` and GitHub will send you a zip archive of the latest version of all files and folders that you see below. If you go to a specific file and click on it GitHub will try to open it, but if this file is of an unrecognised or propietary (closed) format (such as `.xls`, `.xlsx`, `.docx` or `.doc`), it will offer you the option of downloading and viewing the file -- from where you can do your thing using your vendor's overpriced _legacy_ software (such as Excel or Word).

Github will not track the individual changes in propietary files (such as Excel), but it will keep a record of each file committed to the repo. So, if a propietary file is edited, the _entire_ new version of the file will be sent to the repo, not just the changes, as is the case with open text or ascii files. Example of a text file formats are:
* this `INSTRUCTIONS.md` file;
* the QGIS map file format `*.qgs` (it is basically a version of XML), and;
* a source-code file such as an SQL query file `*.sql` or a file Python file `*.py`.

The fact that GitHub's brilliant version control cannot be used on propietary formats is totally painful but is a shortcoming of using office suite products such as spreadsheets, which are a completely innapropriate tool for data storage in the 21st Century!

If you want to work on the files and change them in this repository you will have to _fork_ the repository to create a new **branch** (in Git lingo). You do this by setting up an account on GitHub and by installing Git on your system, then **cloning** the file you want to work on (or the whole repo) to your account and to a local folder on your machine. This cloned 'copy' of the repo or file is referred to as a **branch**. Once you have worked on the file and if both you and the owner are happy with you changes, you can do a **pull request** and the owner can **merge** the two files together.

I am busy working on some VBA to install in each spreadsheet to automatically re-write the entire thing JSON, which is a _much_ better format. The results will look something like the JSON files in the `livelihoods` repo. While the JSON file might not at first appear as user-friendly to the uninitiated as an Excel file does when it's opened in Excel itself, it is machine readable and _does_ allow easy web and app development --I mean, who still has Excel installed on their computers and if they do, can they view Excel spreadsheets on their phones or other devices as well?! This will ultimately leading to massive scaled-out public sharing of HEA data, which can only be a good thing.
