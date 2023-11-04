;; -*- lexical-binding: t -*-
;; Before editing, eval (load-file "test-helper.el")

(ert-deftest rustic-test-format-next-error-last-buffer ()
  (let* ((string "fn main()      {}")
         (buf (rustic-test-count-error-helper-new string))
         (default-directory (file-name-directory (buffer-file-name buf))))
    (with-current-buffer buf
      (erase-buffer)
      (fundamental-mode)
      (should-error (rustic-format-buffer))
      (rustic-mode)
      (insert string)
      (backward-char 10)
      (let ((proc (rustic-format-start-process
                   'rustic-format-sentinel
                   :buffer (current-buffer)
                   :stdin (buffer-string))))
        (with-current-buffer (process-buffer proc)
          (should (eq next-error-last-buffer buf)))
        (while (eq (process-status proc) 'run)
          (sit-for 0.1))
        (sit-for 0.5)))))

(ert-deftest rustic-test-save-some-buffers ()
  (let* ((buffer1 (get-buffer-create "b1"))
         (buffer2 (get-buffer-create "b2"))
         (string "fn main()      {}")
         (formatted-string "fn main() {}\n")
         (dir (rustic-babel-generate-project t))
         (rustic-format-trigger 'on-save)
         (compilation-ask-about-save nil))
    (let* ((default-directory dir)
           (src (concat dir "/src"))
           (file1 (expand-file-name "main.rs" src))
           (file2 (progn (shell-command-to-string "touch src/test.rs")
                         (expand-file-name "test.rs" src))))
      (with-current-buffer buffer1
        (write-file file1)
        (insert string))
      (with-current-buffer buffer2
        (write-file file2)
        (insert string))
      (rustic-save-some-buffers t)
      (sit-for 1)
      (with-current-buffer buffer1
        (should (string= (buffer-string) formatted-string)))
      (with-current-buffer buffer2
        (should (string= (buffer-string) formatted-string))))
    (kill-buffer buffer1)
    (kill-buffer buffer2)))

(ert-deftest rustic-test-save-some-buffers-compilation-ask-about-save ()
(let* ((buffer1 (get-buffer-create "b1"))
         (buffer2 (get-buffer-create "b2"))
         (string "fn main()      {}")
         (formatted-string "fn main() {}\n")
         (dir (rustic-babel-generate-project t))
         (rustic-format-trigger 'on-save)
         (buffer-save-without-query nil)
         (compilation-ask-about-save nil))
    (let* ((default-directory dir)
           (src (concat dir "/src"))
           (file1 (expand-file-name "main.rs" src))
           (file2 (progn (shell-command-to-string "touch src/test.rs")
                         (expand-file-name "test.rs" src))))
      (with-current-buffer buffer1
        (write-file file1)
        (insert string))
      (with-current-buffer buffer2
        (write-file file2)
        (insert string))
      (rustic-save-some-buffers t)
      (sit-for 1)
      (with-current-buffer buffer1
        (should (string= (buffer-string) formatted-string)))
      (with-current-buffer buffer2
        (should (string= (buffer-string) formatted-string))))
    (kill-buffer buffer1)
    (kill-buffer buffer2)))

(ert-deftest rustic-test-compile ()
  (let* ((dir (rustic-babel-generate-project t)))
    (should-not compilation-directory)
    (should-not compilation-arguments)
    (setq compilation-arguments "cargo fmt")
    (let* ((default-directory dir)
           (compilation-read-command nil)
           (proc (rustic-compile)))
      (should (process-live-p proc))
      (while (eq (process-status proc) 'run)
        (sit-for 0.1))
      (should (string= compilation-directory dir))
      (let ((proc (rustic-recompile)))
        (while (eq (process-status proc) 'run)
          (sit-for 0.1)))
      (should (string= (car compilation-arguments) "cargo build"))
      (should (string= compilation-directory dir))))
  (setq compilation-directory nil)
  (setq compilation-arguments nil))

(ert-deftest rustic-test-recompile ()
  (let* ((string "fn main() { let s = 1;}")
         (buf (rustic-test-count-error-helper-new string))
         (default-directory (file-name-directory (buffer-file-name buf)))
         (rustic-format-trigger nil)
         (compilation-read-command nil))
    (with-current-buffer buf
      (let* ((proc (rustic-compile))
             (buffer (process-buffer proc)))
        (while (eq (process-status proc) 'run)
          (sit-for 0.01))
        (should (= 0 (process-exit-status proc)))
        (let ((p (rustic-recompile)))
          (while (eq (process-status proc) 'run)
            (sit-for 0.1))
          (should (= 0 (process-exit-status p))))))))

(ert-deftest rustic-test-backtrace ()
  (kill-buffer (get-buffer rustic-compilation-buffer-name))
  (let* ((string "fn main() {
                       let v = vec![1, 2, 3];
                       v[99];
                    }")
         (default-directory (rustic-test-count-error-helper string)))
    (let ((rustic-compile-backtrace "0")
          (proc (rustic-compilation-start (split-string "cargo run"))))
      (while (eq (process-status proc) 'run)
        (sit-for 0.1))
      (with-current-buffer (get-buffer rustic-compilation-buffer-name)
        (should (= compilation-num-errors-found 1))))
    (let ((rustic-compile-backtrace "1")
          (proc (rustic-compilation-start (split-string "cargo run"))))
      (while (eq (process-status proc) 'run)
        (sit-for 0.1))
      (with-current-buffer (get-buffer rustic-compilation-buffer-name)
        (should (= compilation-num-errors-found 1))))
    (let ((rustic-compile-backtrace "full")
          (proc (rustic-compilation-start (split-string "cargo run"))))
      (while (eq (process-status proc) 'run)
        (sit-for 0.1))
      (with-current-buffer (get-buffer rustic-compilation-buffer-name)
        (should (= compilation-num-errors-found 1))))))
