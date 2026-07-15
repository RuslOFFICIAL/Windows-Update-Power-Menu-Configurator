Windows-Update-Power-Menu Configurator (WUPMC) is a simple project to bypass forced Windows update restart and shut down.
Should work properly on Windows 10 and 11.
If you use release .EXE file, to execute the program, simply run the .EXE file from release.
If you use full .ZIP file, to execute the program, run the file "WUPMC.bat" in the root folder of the project, or run .EXE file in the Program folder.
This project also includes basic method for compiling a file to .EXE file and making a .ZIP file.
I hope someone will find it useful for themselves. :3

If you just want the working Program part, then look at N1 and N2.
If you want also the Setup part, then look at N3 and N4 too.
Version (N1.N2-N3.N4-N5) meaning:
- N1 means a noticeable-big change in the Program part of project.
- N2 means a small change which can be noticed in the code in the Program part of project.
- N3 means a noticeable-big change in the Setup part of project.
- N4 means a small change which can be noticed in the code in the Setup part of project.
- N5 means a little change which does not really matter.

Note about TargetValue. It goes from 0 to 15. To make sure the program will be useful, use decimal numbers in the TargetValue value in Info.conf.
Values for TargetValue is in the next table.
 __________________________
|Decimal|Hexadecimal|Binary|
| :---: |   :---:   |:---: |
|   0   |     0     | 0000 |
|   1   |     1     | 0001 |
|   2   |     2     | 0010 |
|   3   |     3     | 0011 |
|   4   |     4     | 0100 |
|   5   |     5     | 0101 |
|   6   |     6     | 0110 |
|   7   |     7     | 0111 |
|   8   |     8     | 1000 |
|   9   |     9     | 1001 |
|  10   |     a     | 1010 |
|  11   |     b     | 1011 |
|  12   |     c     | 1100 |
|  13   |     d     | 1101 |
|  14   |     e     | 1110 |
|  15   |     f     | 1111 |
 --------------------------
Binary (B1.B2.B3.B4) meaning. 1 means enables, 0 means disabled. More:
 - B1 means the status of "Update and Shutdown" button.
 - B2 means the status of "Shutdown" button.
 - B3 means the status of "Update and Restart" button.
 - B4 means the status of "Restart" button.